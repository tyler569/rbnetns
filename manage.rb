#!/usr/bin/env ruby

require 'netaddr'

class Netns
  attr_reader :name, :lo
  attr_accessor :links

  def self.allns
    `ip netns list`.split.map(&:chomp)
  end

  def initialize(name)
    @links = []
    @name = name
    @lo = nil

    raw_setup unless Netns.allns.include? name
  end

  def link_to(ns)
    Link.new(self, ns)
  end

  def is_default?
    name == "default"
  end

  def exec(cmd)
    puts "#{name}.exec: #{cmd}"
    if is_default?
      `#{cmd}`
    else
      `ip netns exec #{name} #{cmd}`
    end
  end

  def set_lo(net)
    @lo = net
    exec "ip addr add #{net.nth(3).to_s}/64 dev lo"
    exec "ip link set lo up"
  end

  def route(to, via)
    exec "ip route add #{to.to_s} via #{via.to_s}"
  end

  def destroy
    raw_teardown
  end

  private

  def raw_setup
    `ip netns add #{name}` unless is_default?
  end

  def raw_teardown
    `ip netns delete #{name}` unless is_default?
  end
end

class Link
  attr_reader :nss, :net, :num

  @@base = NetAddr::IPv6Net.parse("4::/64")
  @@linknum = 0

  def initialize(*nss, **args)
    @net = args[:net] || @@base
    @num = args[:num] || @@linknum
    @nss = nss

    @@base = @@base.next_sib
    @@linknum += 1

    raw_setup

    nss.each{ |n| n.links << self }
  end

  def names
    nss.map{ |n| "v-#{@num}-#{n.name}" }.reverse
  end

  def myip(ns)
    if ns == nss[0]
      net.nth(2)
    else
      net.nth(1)
    end
  end

  def theirip(ns)
    if ns == nss[0]
      net.nth(1)
    else
      net.nth(2)
    end
  end

  def destroy
    raw_teardown
  end

  private

  def raw_setup
    `ip link add #{names[0]} type veth peer name #{names[1]}`
    (0..1).each do |n|
      `ip link set #{names[n]} netns #{nss[n].name}` unless nss[n].is_default?
      nss[n].exec "ip addr add #{net.nth(n+1).to_s}/64 dev #{names[n]}"
    end
    (0..1).each do |n|
      nss[n].exec "ip link set #{names[n]} up"
    end
  end

  def raw_teardown
    nss[0].exec "ip link delete #{names[0]} type veth"
  end
end

default = Netns.new "default"
blue = Netns.new "blue"

all = NetAddr::IPv4Net.parse("0.0.0.0/0")
all6 = NetAddr::IPv6Net.parse("::/0")

blue.set_lo(NetAddr::IPv6Net.parse("5::/64"))
link = default.link_to blue
blue.route(all6, link.myip(blue))
default.route(blue.lo, link.myip(default))

