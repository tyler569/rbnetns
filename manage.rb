#!/usr/bin/env ruby

require 'ipaddr'

class IPAddr
  def succ_subnet
    n = self.dup
    n.set(self.to_i + (2 << self.prefix-1))
  end

  def +(i)
    self.dup.set(self.to_i + i)
  end

  def -(i)
    self.dup.set(self.to_i - i)
  end

  def to_sub
    self.to_s + "/" + self.prefix.to_s
  end
end

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
    exec "ip addr add #{(net + 2).to_sub} dev lo"
    exec "ip link set lo up"
  end

  def route(to, via)
    exec "ip route add #{to.to_sub} via #{via.to_s}"
  end

  def enable_forwarding
    exec "sysctl net.ipv6.conf.all.forwarding = 1"
    exec "sysctl net.ipv4.ip_forward = 1"
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

  @@base = IPAddr.new "4::/64"
  @@linknum = 0

  def initialize(*nss, **args)
    @net = args[:net] || @@base
    @num = args[:num] || @@linknum
    @nss = nss

    @@base = @@base.succ_subnet
    @@linknum += 1

    raw_setup

    nss.each{ |n| n.links << self }
  end

  def names
    nss.map{ |n| "v-#{@num}-#{n.name}" }.reverse
  end

  def ipof(ns)
    (net + (nss.index(ns)+1)) if nss.include? ns
  end

  def destroy
    raw_teardown
  end

  private

  def raw_setup
    `ip link add #{names[0]} type veth peer name #{names[1]}`
    (0..1).each do |n|
      `ip link set #{names[n]} netns #{nss[n].name}` unless nss[n].is_default?
      nss[n].exec "ip addr add #{(net + (n+1)).to_sub} dev #{names[n]}"
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
red = Netns.new "red"

blue.enable_forwarding
red.enable_forwarding

all = IPAddr.new "0.0.0.0/0"
all6 = IPAddr.new "::/0"

all_los = IPAddr.new "5::/16"

blue.set_lo(IPAddr.new "5::/64")
red.set_lo(IPAddr.new "5:1::/64")

link = default.link_to blue
default.route(all_los, link.ipof(blue))

red.link_to blue

