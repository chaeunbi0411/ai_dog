"""Bounded background jobs so the preview request stays fast and unchanged."""
import io
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

from flask import jsonify, request
from PIL import Image, UnidentifiedImageError


def register_motion_routes(app, build, *, executor=None):
    executor = executor or ThreadPoolExecutor(max_workers=1, thread_name_prefix="pet-motion")
    jobs = {}
    lock = threading.Lock()
    ttl = 3600
    app.config.setdefault("MAX_CONTENT_LENGTH", 8 * 1024 * 1024)
    if app.config["MAX_CONTENT_LENGTH"] is None:
        app.config["MAX_CONTENT_LENGTH"] = 8 * 1024 * 1024

    def run(job_id, image, traits):
        with lock:
            jobs[job_id]["status"] = "running"
        try:
            character = build(image, traits)
            with lock:
                jobs[job_id].update(status="ready", character=character, updated=time.monotonic())
        except Exception:
            app.logger.exception("Character motion generation failed")
            with lock:
                jobs[job_id].update(status="failed", updated=time.monotonic())

    @app.post("/motion-jobs")
    def create_motion_job():
        uploaded = request.files.get("image")
        if uploaded is None:
            return jsonify(error="image is required"), 400
        image = uploaded.read(6 * 1024 * 1024 + 1)
        if len(image) > 6 * 1024 * 1024:
            return jsonify(error="image is too large"), 413
        try:
            with Image.open(io.BytesIO(image)) as preview:
                if preview.format != "PNG" or max(preview.size) > 2048:
                    return jsonify(error="a PNG up to 2048px is required"), 400
                preview.verify()
            seed = int(request.form.get("seed", 42))
            if not 0 <= seed < 2**32:
                raise ValueError("invalid seed")
        except (ValueError, OSError, UnidentifiedImageError, Image.DecompressionBombError):
            return jsonify(error="invalid image or seed"), 400
        traits = {key: request.form.get(key, "")[:300] for key in ("breed", "color", "personality")}
        traits['seed'] = seed
        with lock:
            for key in list(jobs):
                if jobs[key]['status'] in ('ready', 'failed') and time.monotonic() - jobs[key]['updated'] > ttl:
                    del jobs[key]
            if len(jobs) >= 8:
                completed = sorted((k for k in jobs if jobs[k]['status'] in ('ready', 'failed')),
                                   key=lambda k: jobs[k]['updated'])
                if completed:
                    del jobs[completed[0]]
                else:
                    return jsonify(error="busy; retry later"), 503
            job_id = uuid.uuid4().hex
            jobs[job_id] = {"status": "queued", "updated": time.monotonic()}
        try:
            executor.submit(run, job_id, image, traits)
        except RuntimeError:
            with lock:
                del jobs[job_id]
            return jsonify(error="server is stopping; retry later"), 503
        return jsonify(id=job_id), 202

    @app.get("/motion-jobs/<job_id>")
    def get_motion_job(job_id):
        with lock:
            job = jobs.get(job_id)
            if job is None:
                return jsonify(error="job not found"), 404
            result = {k: v for k, v in job.items() if k != 'updated'}
        return jsonify(result)
