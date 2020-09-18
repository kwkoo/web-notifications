# Web Notifications

Simple notifications web app. This is used to simulate a text messaging system in a training environment.

To publish messages using a `GET` request,

```
curl http://localhost:8080/api/send/Hello+World
```

To publish messages using a `PUT` request,

```
curl -XPUT -d 'Hello World' http://localhost:8080/api/send
```
