import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';
import '../models/outfit.dart';
import '../models/outfit_album.dart';

/// Servicio completo para Firebase - Auth, Firestore, Storage
class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;
  String? get userId => currentUser?.uid;

  // ========== AUTENTICACIÓN ==========

  /// Iniciar sesión con email/password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error login: ${e.code} - ${e.message}');
      return null;
    }
  }

  /// Registrar usuario con email/password
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error registro: ${e.code} - ${e.message}');
      return null;
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Enviar email de verificación
  Future<void> sendEmailVerification() async {
    await currentUser?.sendEmailVerification();
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ========== PRENDAS (CLOTHES) ==========

  /// Añade una prenda a Firestore
  Future<DocumentReference?> addClothingItem(ClothingItem item) async {
    if (userId == null) {
      debugPrint('Usuario no autenticado');
      return null;
    }

    try {
      final data = {
        ...item.toJson(),
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      return await _db.collection('users').doc(userId).collection('clothes').add(data);
    } catch (e) {
      debugPrint('Error añadiendo prenda: $e');
      return null;
    }
  }

  /// Sube imagen de prenda a Storage y retorna URL
  Future<String?> uploadClothingImage(File imageFile, String itemId) async {
    if (userId == null) return null;

    try {
      final ref = _storage.ref().child('users').child(userId!).child('clothes').child('$itemId.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Error subiendo imagen: $e');
      return null;
    }
  }

  /// Obtiene stream de prendas del usuario
  Stream<List<ClothingItem>> getClothesStream() {
    if (userId == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(userId)
        .collection('clothes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClothingItem.fromJson(doc.data()))
            .toList());
  }

  /// Obtiene todas las prendas (una vez)
  Future<List<ClothingItem>> getClothes() async {
    if (userId == null) return [];

    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('clothes')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ClothingItem.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo prendas: $e');
      return [];
    }
  }

  /// Actualiza una prenda
  Future<bool> updateClothingItem(String id, Map<String, dynamic> updates) async {
    if (userId == null) return false;

    try {
      await _db.collection('users').doc(userId).collection('clothes').doc(id).update(updates);
      return true;
    } catch (e) {
      debugPrint('Error actualizando prenda: $e');
      return false;
    }
  }

  /// Elimina una prenda
  Future<bool> deleteClothingItem(String id) async {
    if (userId == null) return false;

    try {
      await _db.collection('users').doc(userId).collection('clothes').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Error eliminando prenda: $e');
      return false;
    }
  }

  /// Elimina imagen de Storage
  Future<bool> deleteClothingImage(String itemId) async {
    if (userId == null) return false;

    try {
      final ref = _storage.ref().child('users').child(userId!).child('clothes').child('$itemId.jpg');
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error eliminando imagen: $e');
      return false;
    }
  }

  // ========== OUTFITS ==========

  /// Guarda un outfit
  Future<DocumentReference?> saveOutfit(Outfit outfit) async {
    if (userId == null) return null;

    try {
      final data = {
        ...outfit.toJson(),
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      return await _db.collection('users').doc(userId).collection('outfits').add(data);
    } catch (e) {
      debugPrint('Error guardando outfit: $e');
      return null;
    }
  }

  /// Obtiene stream de outfits
  Stream<List<Outfit>> getOutfitsStream() {
    if (userId == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(userId)
        .collection('outfits')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Outfit.fromJson(doc.data()))
            .toList());
  }

  /// Actualiza outfit
  Future<bool> updateOutfit(String id, Map<String, dynamic> updates) async {
    if (userId == null) return false;

    try {
      await _db.collection('users').doc(userId).collection('outfits').doc(id).update(updates);
      return true;
    } catch (e) {
      debugPrint('Error actualizando outfit: $e');
      return false;
    }
  }

  /// Elimina outfit
  Future<bool> deleteOutfit(String id) async {
    if (userId == null) return false;

    try {
      await _db.collection('users').doc(userId).collection('outfits').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Error eliminando outfit: $e');
      return false;
    }
  }

  // ========== ÁLBUMES DE OUTFITS ==========

  /// Crea álbum de outfits
  Future<DocumentReference?> createAlbum(OutfitAlbum album) async {
    if (userId == null) return null;

    try {
      final data = {
        ...album.toJson(),
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      return await _db.collection('users').doc(userId).collection('albums').add(data);
    } catch (e) {
      debugPrint('Error creando álbum: $e');
      return null;
    }
  }

  /// Obtiene stream de álbumes
  Stream<List<OutfitAlbum>> getAlbumsStream() {
    if (userId == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(userId)
        .collection('albums')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OutfitAlbum.fromJson(doc.data()))
            .toList());
  }

  /// Añade outfit a álbum
  Future<bool> addOutfitToAlbum(String albumId, String outfitId) async {
    if (userId == null) return false;

    try {
      final albumRef = _db.collection('users').doc(userId).collection('albums').doc(albumId);
      await albumRef.update({
        'outfitIds': FieldValue.arrayUnion([outfitId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error añadiendo outfit a álbum: $e');
      return false;
    }
  }

  /// Elimina outfit de álbum
  Future<bool> removeOutfitFromAlbum(String albumId, String outfitId) async {
    if (userId == null) return false;

    try {
      final albumRef = _db.collection('users').doc(userId).collection('albums').doc(albumId);
      await albumRef.update({
        'outfitIds': FieldValue.arrayRemove([outfitId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error eliminando outfit de álbum: $e');
      return false;
    }
  }

  /// Elimina álbum
  Future<bool> deleteAlbum(String id) async {
    if (userId == null) return false;

    try {
      await _db.collection('users').doc(userId).collection('albums').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Error eliminando álbum: $e');
      return false;
    }
  }

  // ========== MEDIDAS DEL USUARIO ==========

  /// Guarda medidas del usuario
  Future<bool> saveUserMeasurements(Map<String, dynamic> measurements) async {
    if (userId == null) return false;

    try {
      await _db.collection('users').doc(userId).set({
        'measurements': measurements,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error guardando medidas: $e');
      return false;
    }
  }

  /// Obtiene medidas del usuario
  Future<Map<String, dynamic>?> getUserMeasurements() async {
    if (userId == null) return null;

    try {
      final doc = await _db.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['measurements'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error obteniendo medidas: $e');
      return null;
    }
  }

  // ========== SINCRONIZACIÓN ==========

  /// Sincroniza datos locales con cloud
  /// Retorna true si hay datos en cloud para descargar
  Future<bool> syncWithCloud() async {
    if (userId == null) return false;

    try {
      // Verificar si hay datos en cloud
      final clothesSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('clothes')
          .get();

      return clothesSnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error sincronizando: $e');
      return false;
    }
  }

  /// Verifica estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}