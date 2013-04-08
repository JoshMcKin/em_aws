EmAws Changelog
=====================

HEAD
=======

0.2.8
=======

- Fix regression for non-pooled requests causing AWS::SimpleDB::Errors::InvalidRequest

0.2.7
=======

- Use update hot_tub requirement

0.2.6
=======

- Use [hot_tub](https://github.com/JoshMcKin/hot_tub) for connection pooling and sessions

0.2.5
=======

- For non-pooled request set em-http-request inactivity_timeout from aws request.read_timeout object. Remove retries based on status 0 [joshmckin, michalf, #13]
- Fetch port from request object [michalf, #13]