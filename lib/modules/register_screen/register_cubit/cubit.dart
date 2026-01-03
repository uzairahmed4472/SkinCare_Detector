import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/modules/register_screen/register_cubit/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/user_model.dart';


class RegisterCubit extends Cubit<RegisterState>
{
  RegisterCubit() : super(initialRegisterState());

  static RegisterCubit get(context) =>BlocProvider.of(context);

  Future<void> userRegister({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    try {
      // First check if email exists
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        emit(errorCreateUserState());
        throw Exception('Email already exists');
      }

      // Create user in Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password
      );

      // Create user document in Firestore
      await creteUser(
        uid: userCredential.user?.uid,
        name: name,
        email: email,
        password: password,
        phone: phone,
      );

      emit(successRegisterState());
    } catch (e) {
      print('Registration error: $e');
      emit(errorCreateUserState());
      throw e;
    }
  }

  Future<void> creteUser({
    required String? uid,
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    UserModel model = UserModel(
      name: name,
      email: email,
      uid: uid,
      password: password,
      phone: phone,
    );

    emit(loadingRegisterState());

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(model.toMap());
      
      emit(successRegisterState());
    } catch (e) {
      emit(errorRegisterState());
      throw e;
    }
  }
}