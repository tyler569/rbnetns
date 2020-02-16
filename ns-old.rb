
class Netns
  attr_reader :name, :links

  @@linknum = 0

  def self.list_all
    `ip netns list`.split.map(&:chomp).append("default")
  end

  def initialize(name)
    @name = name
    @links = []
    raw_create unless Netns.list_all.include? name
  end

  def link(ns)
    raw_link ns.name
    @links << ns
  end

  private

  def raw_create
    `ip netns add #{@name}`
  end

  def raw_exec(*args)
    if @name == "default"
      `#{args.join " "}`
    else
      `ip netns exec #{@name} #{@args.join " "}`
    end
  end

  def new_link_names(other_ns)
    @@linknum += 1
    ["v-#{other_ns}-#{@@linknum}",
     "v-#{@name}-#{@@linknum}"]
  end

  def raw_link(nsname)
    l = new_link_names nsname
    `ip link add #{l[0]} type veth peer name #{l[1]}`
    `ip link set #{l[0]} netns #{@name}` unless @name == "default"
    `ip link set #{l[1]} netns #{nsname}` unless nsname == "default"
  end
end


blue = Netns.new "blue"
red = Netns.new "red"
default = Netns.new "default"
p blue
p red
p default
default.link blue
p blue

