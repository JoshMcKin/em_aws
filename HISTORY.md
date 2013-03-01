EmAws Changelog
=====================

HEAD
=======

0.2.5
=======

- For non-pooled request set em-http-request inactivity_timeout from aws request.read_timeout object. Remove retries based on status 0 [joshmckin, michalf, #13]
- Fetch port from request object [michalf, #13]