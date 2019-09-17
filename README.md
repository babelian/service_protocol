# ServiceProtocol

Basic protocol for communicating between services.

Currently implements HTTP/JSON, see [ServiceProtocol::Redis](https://github.com/babelian/service_protocol) for an alternate adapter.

[![Build Status](https://www.travis-ci.com/babelian/service_protocol.svg?branch=master)](https://www.travis-ci.com/babelian/service_protocol)
[![Maintainability](https://api.codeclimate.com/v1/badges/01d81d612946de92a132/maintainability)](https://codeclimate.com/github/babelian/service_protocol/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/01d81d612946de92a132/test_coverage)](https://codeclimate.com/github/babelian/service_protocol/test_coverage)
[![Inline docs](http://inch-ci.org/github/babelian/service_protocol.svg?branch=master)](http://inch-ci.org/github/babelian/service_protocol)

## Features

* Designed to work with [ServiceOperation](https://babelian.semaphoreci.com/projects/service_operation) but can interface with any class that respond to `.call(params)` and return an object that responds to `#to_hash`.
* Syncronizes metadata (`user_id`, `trace_id`, etc) between services via [RequestStore](https://github.com/steveklabnik/request_store).
* Uses `#to_json` to serialize complex objects in JSON:API format (See Serializtion note below).
* Allows batched requests.


## Example

Call `Math::MultiplyByTwo.call(input: 1)` on the 'math service'

```ruby

ServiceProtocol::Remote.call(
  'math_service:math/multiply_by_two',
  { input: 1 },  # params
  { user_id: 1 } # meta
)

=> { input: 1, output: 2 }
```

## Environment Variables

`SERVICE_PROTOCOL` - Which adapter to use:

* "basic" - in process calls with serialization.
* "lib" - direct calls without serialization.
* "web" - HTTP/JSON.

`SERVICE_PROTOCOL_TOKEN` - A token to share across services to add basic security if service is exposed to public networks. Can be rolled by comma separating tokens (eg "old\_token,new\_token").

## Serialization

Currently `#to_json` expects a hash in JSON:API format:

```json
{ "id" : 1, "type": "ModelName", "attributes": { ... } }
```

To implement this in `ActiveRecord::Base` requires modifying the serialization method:

```ruby

  alias serializable_hash_attributes serializable_hash

  def serializable_hash(options = {})
    attrs = serializable_hash_attributes(options)
    { 'id' => attrs.delete('id'), 'type' => self.class.name.demodulize, 'attributes' => attrs }
  end
```

## Todo

- [ ] Decouple serialization strategy
- [ ] Move environment variables, logger and `Proxy::REQUIRED_META_KEYS` to `Configuration`.
- [ ] Better unit tests.
- [ ] Remove `Hash#traverse` dependency.
- [ ] BaseServer for `authenticates?` method
- [ ] Rename `Proxy` and `Entity`