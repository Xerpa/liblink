# liblink

Elixir messaging library aimed at heteregenous clusters/services with
automatic service discovery and encryption.

## THE PROBLEM

There are two or more services that need to communicate securely in a
request-response fashion with each other. you like erlang/otp but find
that it is not suitable for this particular task. A few reasons that
erlang/otp might not be the best solution:

* placement constraints:

  * erlang distribution assumes a homogenous network;

  * no node discovery/announcement;

  * no load-balacing mechanism;

* security:

  * no authentication mechanism;

  * enabling tls on an erlang distribution might not be a trivial task;

  * you can't limit what kind of tasks a node can perform on the
    cluster;

* performance:

  * it creates a full mesh connection between all participant nodes,
    i.e., in a cluster of $n$ nodes you have $n^2$ connections;

interoperability:

  * you might need to expose a service in a different language;

These aspects are by no means a comprehensive list of requirements you
should consider before making a choice. They may not even make sense
for your application.

Depending on your constraints and current resources, there are
alternatives you might also consider:

* an API built on top of HTTP [e.g.: a RESTful api];

* http://www.release-project.eu/

* https://hexdocs.pm/libcluster/readme.html

* [consul connect](https://www.hashicorp.com/blog/consul-1-2-service-mesh)

## OBJECTIVES

* support multiple message protocols: request-response, publish-subscribe, pipeline;

* support different languages;

* automatic service discovery/announcement;

* possibility to create complex topologies using service metadata;

* built-in, zero-configuration, encryption mechanism;

* built-in authentication mechanism;

* built-in distributed tracing;

## CURRENT IMPLEMENTATION

* protocol support:

  * [X] request-response;
  * [ ] publish-subscribe;
  * [ ] pipeline;

* service discovery:

  * [X] consul backend;

* [ ] multi language support;

* [ ] encryption;

* [ ] authentication;

* [ ] distributed tracing;

## DOCUMENTATION

* https://hex.pm/packages/liblink

## LICENSE

APACHE-2.0

## CONTRIBUTORS

* [AUTHORS.md](AUTHORS.md)
