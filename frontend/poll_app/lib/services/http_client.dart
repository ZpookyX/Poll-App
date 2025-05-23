import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

Dio createClient() {
  final baseUrl = Platform.isAndroid
      ? 'http://10.0.2.2:5080'
      : 'http://localhost:5080';

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {'Content-Type': 'application/json'},
    validateStatus: (status) => status != null && status < 500,
  ));

  dio.interceptors.add(CookieManager(CookieJar()));
  return dio;
}
