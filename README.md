# ServiceProtocol

Basic protocol for communicating between services via HTTP/JSON.


[![Build Status](https://www.travis-ci.com/babelian/service_protocol.svg?branch=master)](https://www.travis-ci.com/babelian/service_protocol)

[![Maintainability](https://api.codeclimate.com/v1/badges/01d81d612946de92a132/maintainability)](https://codeclimate.com/github/babelian/service_protocol/maintainability)

[![Test Coverage](https://api.codeclimate.com/v1/badges/01d81d612946de92a132/test_coverage)](https://codeclimate.com/github/babelian/service_protocol/test_coverage)

[![Inline docs](http://inch-ci.org/github/babelian/service_protocol.svg?branch=master)](http://inch-ci.org/github/babelian/service_protocol)

## Features

* Designed to work with [ServiceOperation](https://babelian.semaphoreci.com/projects/service_operation) but can call any class that respond to `.call(params)`
* Syncronizes metadata (`user_id`, `trace_id`, etc) between services via [RequestStore](https://github.com/steveklabnik/request_store)
* Uses `#to_json` to serializes complex objects in JSON:API format.
* [Redis Adapter](https://github.com/babelian/service_protocol)
* Allows batched requests.


## Example

Call `Math::MultiplyByTwo.call(input: 1)` on the 'math service'

```ruby

ServiceProtocol::RemoteAction.call(
  'math_service:math/multiply_by_two',
  { input: 1 },  # params
  { user_id: 1 } # meta
)

=> { input: 1, output: 2 }
```