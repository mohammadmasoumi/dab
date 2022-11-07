# Dab

![alt text](resources/dab2.jpeg)

Managing your outgoing web connections from Fly with Smokescreen

<!-- cut here-->

## Rationale

This example runs [Stripe's Smokescreen proxy](https://github.com/stripe/smokescreen) on Fly, with appropriate modifications to add basic password control.

It is always worthwhile to control the outgoing traffic from your other applications. If your apps call other systems with user-entered URLs, say for triggering webhooks or reading responses from an API, then there is a possibility that that feature could be abused. A bad actor could enter URLs designed to access resources inside your application's private network, giving it the names of known machines or well-known private IP addresses. Depending on how your app responds may give that bad actor a clue on how your application works and from that, possibly stage an attack.

To handle this, Stripe created (and open-sourced), Smokescreen, an outbound proxy that makes sure that requests to the outside world from your applications aren't trying to probe your internal network. Out of the box, Smokescreen will check any request isn't destined for 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16" or fc00::/7. There's a lot more that Smokescreen can do around roles, ACLs, and TLS certificates, but that is outside the scope of this example.

## The Dockerfile

One thing with Smokescreen is that there is no binary executable distributed for it. That means it has to be built to deploy it. This example comes with a Dockerfile that does a multi-stage build - first compiling the code, then moving the executable to a clean image to run.

## Deploying on Fly

The quickest way to initialize the app is to import the `fly.source.toml` file supplied:

```
fly init smokescreen-example --import fly.source.toml
```

Replace `smokescreen-example` with your preferred app name (`yourappname`) or omit it to have Fly generate a name for you. You may be prompted for which organization you want the app to run in. Ensure that it is running in the same organization as the apps you wish to manage their external calls.

Smokescreen runs on port 4750 and applications wishing to connect to it from within your Fly organization should send their requests to `yourappname.internal`. To connect to Smokescreen from outside the Fly environment, use [Fly's Wireguard](https://fly.io/docs/reference/wireguard/) to create a VPN into your Fly organization.

This Smokescreen example includes support for a proxy password and an access control list.

Before you deploy Smokescreen, you'll need to set a Fly secret for the proxy password; if it is not set, Smokescreen will exit immediately.

```
fly secrets set PROXY_PASSWORD=yourpassword
```

To bring Smokescreen online, run:

```
fly deploy
```

## Testing

To test Smokescreen is running correctly, you can use `curl`. The -x option on curl tells it to use the following address and port as a proxy.

As Smokescreen has a password set, we also have to use the -U option to send our password. Therefore the command:

```bash
curl -U anyname:yourpassword -x yourappname.internal:4750 https://fly.io
```

Would attempt to use the proxy to contact the secure version of the fly.io site. It'll echo back the contents of the front page.

Remember for this to work, you'll need to configure a Wireguard VPN into your Fly organization. If you don't, the `.internal` host name resolution will not work.

If an attempt was made to connect to `localhost`, as a network mapper may do, this would happen:

```bash
curl -U anyname:yourpassword -x yourappname.internal:4750 http://localhost/
Egress proxying is denied to host 'localhost': The destination address (127.0.0.1) was denied by rule 'Deny: Not Global Unicast'. destination address was denied by rule, see error.
```

## Notes

- The configuration shown is an example, with a simple password lock on the authentication. As it currently stands, if the connection is "authed" (that is, has a valid password), then the ACL will let the connection take place and note it in the logs:

```yaml
---
version: v1
services:
  - name: authed
    project: users
    action: report

default:
  project: other
  action: enforce
```

The `enforce` action only allows connections to sites in the `allowed_domains` list (which as there aren't any, means it blocks all unauthorized connections). Read more about ACLs in the [Smokescreen README](https://github.com/stripe/smokescreen#acls).

The `authed` users requests have a `report` action which allows the connection to be made and logs information about that connection. Running `fly logs` will show entries like this:

```log
2021-01-13T11:35:13.843Z be1e33dd lhr [info] time="2021-01-13T11:35:13Z" level=info msg=CANONICAL-PROXY-DECISION allow=true content_length=0 decision_reason="rule has allow and report policy" dst_ip="2a09:8280:1:a270:b8f5:b9f7:8891:f3" dst_port=443 enforce_would_deny=true id=bvvdlsd11c3s4uipn73g project=users proxy_type=connect requested_host="fly.io:443" role=authed source_addr="[fdaa:0:4:a7b:dc6:0:a:2]:53137" src_host="fdaa:0:4:a7b:dc6:0:a:2" src_host_common_name=unknown src_host_organization_unit=unknown src_port=53137 start_time="2021-01-13 11:35:13.865538649 +0000 UTC" trace_id=
2021-01-13T11:35:14.022Z be1e33dd lhr [info] time="2021-01-13T11:35:14Z" level=info msg=CANONICAL-PROXY-CN-CLOSE bytes_in=0xc000137310 bytes_out=0xc000137318 dst_ip="2a09:8280:1:a270:b8f5:b9f7:8891:f3" dst_port=443 duration=0.170710048 end_time="2021-01-13 11:35:14.062381945 +0000 UTC" error= id=bvvdlsd11c3s4uipn73g last_activity="2021-01-13 11:35:14.062118835 +0000 UTC" proxy_type=connect requested_host="fly.io:443" role=authed source_addr="[fdaa:0:4:a7b:dc6:0:a:2]:53137" start_time="2021-01-13 11:35:13.865538649 +0000 UTC" trace_id=
```

The first entry records the connection being allowed, the second the completion of that connection.

## Discuss

- Discuss the Smokescreen example on its [dedicated community.fly.io topic](https://community.fly.io/t/new-smokescreen-example/466)
