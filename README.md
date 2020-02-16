## rbnetns

rbnetns is a wrapper around linux network namespaces and veth links. It is designed to make creating complicated namespace topologies easy for testing routing protocols or forwarders.

### Sample code:

Currently, rbnetns is not wrapped into a gem or anything - I intend to do so in the future.

For the moment, you can just edit the `manage.rb` file with code:


```rb
names = ['red', 'blue', 'green']

ns = names.map do |name|
  Netns.new name
end

ns.each_cons(2) do |ns1, ns2|
  ns1.link_to ns2
end

default = Netns.new "default"
default.link_to ns[0]

# Toplogy
#
# host system <-- link --> red <--> blue <--> green

```

At the end of that snippet, the red namespace is connected to the host system by aveth interface, and it is then connected to the green and blue namespaces.

Each interface has an automatically assigned IPv6 /64, but no other routing is set up - the idea is that if this is being used to test a routing protocol code running in the namespaces would want to set up routing itself.

This project is very new and should not be used for anything serious.
