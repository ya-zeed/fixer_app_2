import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendEmail(String email, String subject, String text) async {
  try {
    final response = await http.post(
      Uri.parse('http://mailer.yt.sa/api/send-email'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'email': email,
        'subject': subject,
        'text': text,
      }),
    );
    if (response.statusCode == 200) {
      print('Email sent successfully');
    } else {
      print('Failed to send email');
    }
  } catch (e) {
    print('Error sending email: $e');
  }
}
