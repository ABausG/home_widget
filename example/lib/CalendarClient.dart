import 'package:flutter/material.dart';
import "package:googleapis_auth/auth_io.dart";
import 'package:googleapis/calendar/v3.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarClient {
  static const _scopes = const [CalendarApi.calendarEventsScope];
  //static const _scopes = const [CalendarApi.CalendarEventsScope];

  insert(title, startTime, endTime) {
//       "878169543212-ugngo0bm18hu3lh83nk76bidts9c4q2r.apps.googleusercontent.com",
    var _clientID = new ClientId("705466691919-h57354jvl6b4a89ivqiegmjcrtnb474k.apps.googleusercontent.com", null);
    clientViaUserConsent(_clientID, _scopes, prompt).then((AuthClient client) {
      var calendar = CalendarApi(client);
      calendar.calendarList.list().then((value) => print("VAL________$value"));

      String calendarId = "primary";
      Event event = Event(); // Create object of event

      event.summary = title;

      EventDateTime start = new EventDateTime();
      start.dateTime = startTime;
      start.timeZone = "GMT+05:00";
      event.start = start;

      EventDateTime end = new EventDateTime();
      end.timeZone = "GMT+05:00";
      end.dateTime = endTime;
      event.end = end;
      try {
        calendar.events.insert(event, calendarId).then((value) {
          print("ADDEDDD_________________${value.status}");
          if (value.status == "confirmed") {
            print('Event added in google calendar');
          } else {
            print("Unable to add event in google calendar");
          }
        });
      } catch (e) {
        print('Error creating event $e');
      }
    });
  }

  void prompt(String url) async {
    print("Please go to the following URL and grant access:");
    print("  => $url");
    print("");

    //if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    //} else {
    //  throw 'Could not launch $url';
    //}
  }
}
