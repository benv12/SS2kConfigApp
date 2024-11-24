import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../config/env.dart';

class StravaService {
  static const String _baseUrl = 'https://www.strava.com/api/v3';
  static const String _authUrl = 'https://www.strava.com/oauth/authorize';
  static const String _tokenUrl = 'https://www.strava.com/oauth/token';
  
  // Keys for storing tokens in SharedPreferences
  static const String _accessTokenKey = 'strava_access_token';
  static const String _refreshTokenKey = 'strava_refresh_token';
  static const String _expiresAtKey = 'strava_expires_at';

  // Get stored tokens
  static Future<Map<String, String?>> getStoredTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'accessToken': prefs.getString(_accessTokenKey),
      'refreshToken': prefs.getString(_refreshTokenKey),
      'expiresAt': prefs.getString(_expiresAtKey),
    };
  }

  // Store tokens
  static Future<void> _storeTokens(String accessToken, String refreshToken, String expiresAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_expiresAtKey, expiresAt);
  }

  // Clear stored tokens
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_expiresAtKey);
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final tokens = await getStoredTokens();
    if (tokens['accessToken'] == null) return false;
    
    // Check if token is expired
    if (tokens['expiresAt'] != null) {
      final expiresAt = int.parse(tokens['expiresAt']!);
      if (DateTime.now().millisecondsSinceEpoch / 1000 >= expiresAt) {
        // Token is expired, try to refresh
        return await _refreshToken(tokens['refreshToken']!);
      }
    }
    
    return true;
  }

  // Refresh token
  static Future<bool> _refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'client_id': Environment.stravaClientId,
          'client_secret': Environment.stravaClientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _storeTokens(
          data['access_token'],
          data['refresh_token'],
          data['expires_at'].toString(),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return false;
    }
  }

  // Start OAuth flow
  static Future<void> authenticate(BuildContext context) async {
    // Show instructions dialog
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connecting to Strava'),
        content: const Text(
          'You will be redirected to Strava to authorize SmartSpin2k.\n\n'
          'After authorizing, please select "Open in SmartSpin2k" when prompted.',
        ),
        actions: [
          TextButton(
            child: const Text('CONTINUE'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );

    final url = '$_authUrl?'
        'client_id=${Environment.stravaClientId}&'
        'redirect_uri=http://localhost&'
        'response_type=code&'
        'approval_prompt=force&'
        'scope=activity:write,read&'
        'mobile=true';

    debugPrint('Attempting to launch Strava auth URL');
    debugPrint('Client ID: ${Environment.stravaClientId}');
    debugPrint('URL: $url');

    try {
      if (await canLaunchUrlString(url)) {
        final result = await launchUrlString(
          url,
          mode: LaunchMode.externalApplication,
        );
        debugPrint('URL launch result: $result');
      } else {
        debugPrint('Cannot launch URL: $url');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to launch Strava authentication. Please check your internet connection.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching Strava authentication: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle OAuth callback
  static Future<bool> handleAuthCallback(String code) async {
    debugPrint('Handling auth callback with code: $code');
    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'client_id': Environment.stravaClientId,
          'client_secret': Environment.stravaClientSecret,
          'code': code,
          'grant_type': 'authorization_code',
        },
      );

      debugPrint('Auth callback response status: ${response.statusCode}');
      debugPrint('Auth callback response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _storeTokens(
          data['access_token'],
          data['refresh_token'],
          data['expires_at'].toString(),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Auth callback error: $e');
      return false;
    }
  }

  // Upload activity
  static Future<bool> uploadActivity(String filePath, String name, String description) async {
    if (!await isAuthenticated()) return false;

    try {
      final tokens = await getStoredTokens();
      final accessToken = tokens['accessToken'];
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/uploads'),
      );

      request.headers['Authorization'] = 'Bearer $accessToken';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
      ));
      
      request.fields['data_type'] = 'fit';
      request.fields['name'] = name;
      request.fields['description'] = description;

      final response = await request.send();
      debugPrint('Upload response status: ${response.statusCode}');
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Upload activity error: $e');
      return false;
    }
  }
}
