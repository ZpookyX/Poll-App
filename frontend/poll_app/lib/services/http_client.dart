import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

// The cookie jar is needed to make cookies persist between requests
final CookieJar _cookieJar = CookieJar();

// Here we define the createClient / dio instance that is used in api.dart to
// use HTTP in dart
Dio createClient() {
  // Android uses the base url 10.0.2.2 while on desktop and ios we can do
  // localhost directly
  final baseUrl = Platform.isAndroid
      ? 'http://10.0.2.2:5080'
      : 'http://localhost:5080';

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {'Content-Type': 'application/json'},
    // We got a lot of errors that weren't actual issues
    // So this makes sure that those dont come up
    // May be a temporary solution?
    validateStatus: (status) => status != null && status < 500,
  ));

  dio.interceptors.add(CookieManager(_cookieJar));
  return dio;
}
