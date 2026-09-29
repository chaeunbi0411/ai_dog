import base64
import io
import unittest

import numpy as np
from PIL import Image, ImageDraw
from flask import Flask

from motion_generation import aligned, build_character, transition
from motion_jobs import register_motion_routes


def drawing(shift=0):
    image = Image.new('RGBA', (256, 256))
    draw = ImageDraw.Draw(image)
    draw.ellipse((50, 60 + shift, 190, 210), fill=(160, 90, 30, 255))
    draw.rectangle((80, 100, 110, 130), fill=(250, 250, 250, 255))
    return image


def image_bytes():
    buffer = io.BytesIO()
    drawing().save(buffer, format='PNG')
    return buffer.getvalue()


class ImmediateExecutor:
    def submit(self, fn, *args):
        fn(*args)


class MotionTests(unittest.TestCase):
    def test_normalization_and_transition_preserve_endpoints_and_alpha(self):
        a, b = aligned(drawing()), aligned(drawing(30))
        self.assertEqual(a.size, (256, 256))
        self.assertEqual(a.getbbox()[3], 240)
        frames = transition(a, b)
        self.assertTrue(np.array_equal(frames[0], a))
        self.assertTrue(np.array_equal(frames[-1], b))
        self.assertEqual(frames[3].getpixel((0, 0))[3], 0)
        self.assertFalse(np.array_equal(frames[3], a))

    def test_every_clip_belongs_to_original_preview_and_transitions_join(self):
        preview = image_bytes()
        references = []
        def generate(reference, prompt):
            references.append(reference.tobytes())
            return drawing(20)
        result = build_character(preview, generate)
        self.assertEqual(base64.b64decode(result['preview']), preview)
        self.assertEqual(len(references), 6)
        self.assertEqual(len(set(references)), 1)
        clips = result['clips']
        self.assertEqual(len(clips), 15)
        idle = clips['idle']['frames'][0]
        self.assertEqual(clips['walk']['frames'][0], idle)
        for action in ('feed', 'wash', 'play', 'sleep'):
            entry, loop, leave = [clips[action + suffix] for suffix in ('_enter', '', '_exit')]
            self.assertEqual(entry['frames'][0], idle)
            self.assertEqual(entry['frames'][-1], loop['frames'][0])
            self.assertEqual(leave['frames'][0], loop['frames'][0])
            self.assertEqual(leave['frames'][-1], idle)
            self.assertFalse(entry['loop'])
            self.assertTrue(loop['loop'])
            self.assertGreater(len(set(loop['frames'])), 1)
        for clip in clips.values():
            for frame in clip['frames']:
                with Image.open(io.BytesIO(base64.b64decode(frame))) as image:
                    self.assertIn('transparency', image.info)
                    self.assertEqual(image.convert('RGBA').getpixel((0, 0))[3], 0)
                    self.assertEqual(image.size, (256, 256))


class JobTests(unittest.TestCase):
    def app(self, build):
        app = Flask(__name__)
        app.config['TESTING'] = True
        register_motion_routes(app, build, executor=ImmediateExecutor())
        return app.test_client()

    def test_request_uses_uploaded_preview_and_polls_ready(self):
        seen = []
        def build(image, traits):
            seen.append((image, traits))
            return {'version': 1}
        client = self.app(build)
        response = client.post('/motion-jobs', data={
            'image': (io.BytesIO(image_bytes()), 'preview.png'), 'breed': 'poodle', 'seed': '23'})
        self.assertEqual(response.status_code, 202)
        result = client.get('/motion-jobs/' + response.json['id'])
        self.assertEqual(result.json['status'], 'ready')
        self.assertEqual(seen[0][0], image_bytes())
        self.assertEqual(seen[0][1]['seed'], 23)

    def test_failure_is_reported_without_partial_character(self):
        def build(*args):
            raise RuntimeError('GPU unavailable')
        client = self.app(build)
        response = client.post('/motion-jobs', data={'image': (io.BytesIO(image_bytes()), 'dog.png')})
        result = client.get('/motion-jobs/' + response.json['id']).json
        self.assertEqual(result['status'], 'failed')
        self.assertNotIn('character', result)

    def test_invalid_input_never_starts_generation(self):
        def build(*args):
            self.fail('invalid request started generation')
        client = self.app(build)
        self.assertEqual(client.post('/motion-jobs').status_code, 400)
        self.assertEqual(client.post('/motion-jobs', data={
            'image': (io.BytesIO(b'not a PNG'), 'dog.png')}).status_code, 400)
        self.assertEqual(client.post('/motion-jobs', data={
            'image': (io.BytesIO(image_bytes()), 'dog.png'), 'seed': '-1'}).status_code, 400)
        self.assertEqual(client.get('/motion-jobs/missing').status_code, 404)

    def test_queue_is_bounded(self):
        class PendingExecutor:
            def submit(self, *args):
                pass
        app = Flask(__name__)
        register_motion_routes(app, lambda *args: None, executor=PendingExecutor())
        client = app.test_client()
        for _ in range(8):
            self.assertEqual(client.post('/motion-jobs', data={
                'image': (io.BytesIO(image_bytes()), 'dog.png')}).status_code, 202)
        self.assertEqual(client.post('/motion-jobs', data={
            'image': (io.BytesIO(image_bytes()), 'dog.png')}).status_code, 503)


if __name__ == '__main__':
    unittest.main()
