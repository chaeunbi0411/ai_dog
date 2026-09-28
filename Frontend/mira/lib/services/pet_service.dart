import 'package:cloud_firestore/cloud_firestore.dart';

class PetService {
  PetService._();
  static final instance = PetService._();

  final _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String familyId) => _firestore
      .collection('families')
      .doc(familyId)
      .collection('pet')
      .doc('profile');

  Future<Map<String, dynamic>?> fetchPet(String familyId) async {
    final snapshot = await _doc(familyId).get();
    return snapshot.data();
  }

  Stream<Map<String, dynamic>?> watchPet(String familyId) {
    return _doc(familyId).snapshots().map((snapshot) => snapshot.data());
  }

  Future<void> savePet({
    required String familyId,
    required String updatedByUid,
    required String name,
    required String breed,
    required String colorDescription,
    required String personality,
    String? gender,
    String? preferredAddress,
    Map<String, dynamic>? personalityProfile,
  }) {
    return _doc(familyId).set({
      'name': name,
      'breed': breed,
      'colorDescription': colorDescription,
      'personality': personality,
      'gender': ?gender,
      if (preferredAddress != null)
        'addresses': {updatedByUid: preferredAddress.trim()},
      'personalityProfile': ?personalityProfile,
      'updatedBy': updatedByUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
