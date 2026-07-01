-----

date: 25-04-26

-----

# Building a reverse proxy server using Hummingbird

I built a reverse proxy server. Yes I could and probably should use
[nginx](https://nginx.org) for this but I find I learn a lot from building my
own simple version of things.

## Motivation & Self hosting

My motivation for this is I am self-hosting a website as I wanted to better
understand what AWS and other cloud providers give you. I understand they give
you a lot, especially with hosting global distributed systems and managed
databases, but does every website need all that complexity? I also figured I
could always move any of these projects to a cloud solution if needed.

To self-host and serve a website you need your own SSL certificates as well as
pointing your domain name to your server. This is done using Domain Name Server
(DNS) records and the IP address of the server.

For self-hosting, I recommend using Cloud Flare as you can
[create](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/create/)
DNS records for your domain that point to your IP address with a simple cron
job making API requests.

To get your SSL certificates for your website so you can server secure (HTTPS)
connections you can use [certbot](https://certbot.eff.org).

This was easy enough and originally building a site using the Hummingbird http2
example as a starting place I was able to get a secure website loaded from a
home computer.

> I thought this was very cool when I got it working. Especially when I set up
> the ability to ssh into the machine. Making sure to close the door behind me.

After having this site up for a few weeks I found it very annoying to work on
and develop a site that expects HTTPS connections. I remembered that most
people put nginx in front of their site and looked into how that worked and
realized all nginx really was, was another server that had the SSL certificates
that forward connections to a server behind it.

Remembering that the server framework (Hummingbird) I had been using had a
[proxy server example](https://github.com/hummingbird-project/hummingbird-examples/tree/main/proxy-server)
. I started poking around at how it works, forwarding traffic to another
server behind it.

## Docker

To make deploying these two servers easier, and have some composability to them
I ended up setting up docker on the host machine and I am using
`docker compose` to run the servers. In doing so I learned how to set a network
between containers which I can use to host other servers and database
connections for projects as I go.

> Here are the two docker compose files I have between the proxy server and the
> real server.

```yml
# proxy-docker-compose.yml
services:
  proxy:
    build: .
    ports:
 - 443:8000
    networks:
 - internal-network
networks:
  internal-network:
    external: true
```

```yml
# backend-docker-compose.yml
services:
  shape-tree:
    build: .
    ports:
 - 8001:8001
    networks:
 - internal-network
networks:
  internal-network:
    external: true
```

Pleased with myself for getting this working and it was easier than I expected.

## Server Name Indication (SNI)

Knowing I have added a lot of complexity and indirection from where I was of
simply running the server on the Linux computer as a daemon and listening to
forwarded traffic from my router. I began thinking about how I could expose
other servers and backends through this proxy as that’s one thing that nginx
allows you to do.

From my quick searching of how I could nginx achieves this and some insight of
how I could do this. The solution is very simple you just route the traffic
based on the `host` part of the HTTP request.

My follow-up question was can I use one set of certificates for multiple
websites or does each website need its own certificates and how can I change
which certificates get used for each request.

This is where I learned about SNI or
[Server Name Indication](https://en.wikipedia.org/wiki/Server_Name_Indication).
SNI An extension of the TLS protocol, which is the protocol that allows HTTPS
connection to be made with our SSL certificates. Poking into the Swift NIO and
Hummingbird codebases, for SNI to see if it was possible to hook into this part
of the server without completely giving up what Hummingbird is providing for
me. I figured out that I could hook into where Hummingbird sets up your HTTPS
configuration.

> I did find a small typo in the
> [swift-nio-ssl](https://github.com/apple/swift-nio-ssl/pull/534) library.

## Hummingbird & `HTTPServerBuilder`

When building a Hummingbird server you setup your HTTP routes like you would
with most server libraries. Passing that router into an `Application` which
builds and setups the server.

```swift
// Copied from https://hummingbird.codes
import Hummingbird

let router = Router().get { req, context in
    return "Hello, Swift!"
}
let app = Application(router: router)
try await app.runService()
```

To upgrade this basic Hummingbird server to server HTTPS traffic using our
certificates from certbot. You use a `HTTPServerBuilder.http2Upgrade` which you
pass in a `TLSConfiguration` that sets up your SSL certificates. Looking
something like the following.

```swift
var tlsConfiguration: TLSConfiguration {
  get throws {
      let certificateChain = try NIOSSLCertificate.fromPEMFile("path-to/server.crt")
      let privateKey = try NIOSSLPrivateKey(file: "path-to/server.key", format: .pem)
      return TLSConfiguration.makeServerConfiguration(
          certificateChain: certificateChain.map { .certificate($0) },
          privateKey: .privateKey(privateKey))
  }
}

let app = try Application(
        router: router,
        server: .http2Upgrade(tlsConfiguration: tlsConfiguration))
try await app.runService()
```

From my spelunking of SwiftNIO and Hummingbird, I learned that I can override
the `sslContextCallback` function on the `tlsConfiguration` with something like
the following.

```swift
tlsConfiguration.sslContextCallback = { (values, promise) in
  if let hostname = values.serverHostname {
    if hostname == "domain-name.org" {
      promise.completeWithTask {
        var override = NIOSSLContextConfigurationOverride()
        override.certificateChain = certificateChain.map { .certificate($0) }
        override.privateKey = .privateKey(privateKey)
        return override
      }
    } else {
      // Serve other set of certificates.
    }
  }
  promise.completeWithTask {
    // Return empty certs, triggers insecure access.
    return NIOSSLContextConfigurationOverride()
    // security hole ...
  }
}
```

Combining this hook with some logic in the proxy middleware to require
connections to be HTTPS as well as have the hostname of the request match the
hostname in our SNI value logic otherwise, we server a `400 Bad Request`. If
everything matches up we forward the request.

Well this might not be built proof it seems to be sound enough for my basic
need and leaves a path to adding other domain names to this little proxy
server.

## Closing thoughts

I thought this was a fun little project as I haven’t really heard of anyone
building their own reverse proxy with the convention being “just use nginx”.
Which is probably a better solution than writing your own. But I’m pretty
excited about this not to mention I can expand on this down the road with
Swift’s [distributed actors](https://www.swift.org/blog/distributed-actors/) to
remotely managed this and the servers behind it creating my own little
distributed system orchestration.

Thanks for reading, Zane.

[Leave Feedback](https://github.com/zaneenders/articles/edit/main/building-a-reverse-proxy-server-using-hummingbird.md)
