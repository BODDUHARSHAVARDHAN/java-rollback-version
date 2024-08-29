package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

@RestController()
public class Greetings {

    private static final LocalTime MORNING = LocalTime.of(0, 0, 0);
    private static final LocalTime AFTER_NOON = LocalTime.of(12, 0, 0);
    private static final LocalTime EVENING = LocalTime.of(16, 0, 0);
    private static final LocalTime NIGHT = LocalTime.of(21, 0, 0);

    @GetMapping("/api/greeting")
    public String getGreetings() {
        return "Hey, Welcome to spring boot application.!";
    }

    @GetMapping("/api/time_now")
    public String getTime() {

        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("HH:mm");
        LocalTime now = LocalTime.now();

        StringBuilder builder = new StringBuilder("It's ").append(now.format(formatter)).append(" ");
        if (between(MORNING, AFTER_NOON, now)) {
            builder.append("Good Morning");
        } else if (between(AFTER_NOON, EVENING, now)) {
            builder.append("Good Afternoon");
        } else if (between(EVENING, NIGHT, now)) {
            builder.append("Good Evening");
        } else {
            builder.append("Good Night");
        }
        return builder.toString();
    }

    private boolean between(LocalTime start, LocalTime end, LocalTime now) {
        return (!now.isBefore(start)) && now.isBefore(end);
    }
}
