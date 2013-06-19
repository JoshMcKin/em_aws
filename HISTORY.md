EmAws Changelog
=====================

HEAD
=======

- check for Aws.config.logger when setting HotTub.logger [kybishop #21]
- Clean up specs [kybishop #22]

0.3.0
=======

- requires AWS-SDK 1.9.3 for thread saftey issues in 1.9.0-1.9.2
- refactors client API to expose EM-Http-Request client options directly

0.2.9
=======

- AWS-SDK 1.9+ breaks EmAws 0.2, require AWS-SDK <= 1.8.5

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