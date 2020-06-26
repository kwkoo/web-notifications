# Web Notifications

Simple notifications web app.

To publish messages using a `GET` request,

```
curl http://localhost:8080/api/send/Hello+World
```

To publish messages using a `PUT` request,

```
curl -XPUT -d 'Hello World' http://localhost:8080/api/send
```
