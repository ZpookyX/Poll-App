// Web-only client using browser cookies (for session-based auth)
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

http.Client createClient() => BrowserClient()..withCredentials = true;