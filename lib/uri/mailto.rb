#
# = uri/mailto.rb
#
# Author:: Akira Yamada <akira@ruby-lang.org>
# License:: You can redistribute it and/or modify it under the same term as Ruby.
# Revision:: $Id$
#

require 'uri/generic'

module URI

  #
  # RFC2368, The mailto URL scheme
  #
  class MailTo < Generic
    include REGEXP

    DEFAULT_PORT = nil

    COMPONENT = [ :scheme, :to, :headers ].freeze

    # :stopdoc:
    #  "hname" and "hvalue" are encodings of an RFC 822 header name and
    #  value, respectively. As with "to", all URL reserved characters must
    #  be encoded.
    #
    #  "#mailbox" is as specified in RFC 822 [RFC822]. This means that it
    #  consists of zero or more comma-separated mail addresses, possibly
    #  including "phrase" and "comment" components. Note that all URL
    #  reserved characters in "to" must be encoded: in particular,
    #  parentheses, commas, and the percent sign ("%"), which commonly occur
    #  in the "mailbox" syntax.
    #
    #  Within mailto URLs, the characters "?", "=", "&" are reserved.

    # hname      =  *urlc
    # hvalue     =  *urlc
    # header     =  hname "=" hvalue
    HEADER_PATTERN = "(?:[^?=&]*=[^?=&]*)".freeze
    HEADER_REGEXP  = Regexp.new(HEADER_PATTERN, 'N').freeze
    # headers    =  "?" header *( "&" header )
    # to         =  #mailbox
    # mailtoURL  =  "mailto:" [ to ] [ headers ]
    MAILBOX_PATTERN = "(?:#{PATTERN::ESCAPED}|[^(),%?=&])".freeze
    MAILTO_REGEXP = Regexp.new(" # :nodoc:
      \\A
      (#{MAILBOX_PATTERN}*?)                          (?# 1: to)
      (?:
        \\?
        (#{HEADER_PATTERN}(?:\\&#{HEADER_PATTERN})*)  (?# 2: headers)
      )?
      \\z
    ", Regexp::EXTENDED, 'N').freeze
    # :startdoc:

    #
    # == Description
    #
    # Creates a new URI::MailTo object from components of URI::MailTo
    # with check.  It is to and headers. It provided by an Array of a
    # Hash. You can provide headers as String like
    # "subject=subscribe&cc=addr" or Array like [["subject",
    # "subscribe"], ["cc", "addr"]]
    #
    def self.build(args)
      tmp = Util::make_components_hash(self, args)

      if tmp[:to]
        tmp[:opaque] = tmp[:to]
      else
        tmp[:opaque] = ''
      end

      if tmp[:headers]
        tmp[:opaque] << '?'

        if tmp[:headers].kind_of?(Array)
          tmp[:opaque] << tmp[:headers].collect { |x|
            if x.kind_of?(Array)
              x[0] + '=' + x[1..-1].to_s
            else
              x.to_s
            end
          }.join('&')

        elsif tmp[:headers].kind_of?(Hash)
          tmp[:opaque] << tmp[:headers].collect { |h,v|
            h + '=' + v
          }.join('&')

        else
          tmp[:opaque] << tmp[:headers].to_s
        end
      end

      return super(tmp)
    end

    #
    # == Description
    #
    # Creates a new URI::MailTo object from ``generic'' components with
    # no check. Because, this method is usually called from URI::parse
    # and the method checks validity of each components.
    #
    def initialize(*arg)
      super(*arg)

      @to = nil
      @headers = []

      if MAILTO_REGEXP =~ @opaque
         if arg[-1]
          self.to = $1
          self.headers = $2
        else
          set_to($1)
          set_headers($2)
        end

      else
        raise InvalidComponentError,
          "unrecognised opaque part for mailtoURL: #{@opaque}"
      end
    end
    attr_reader :to
    attr_reader :headers

    def check_to(v)
      return true unless v
      return true if v.size == 0

      if OPAQUE !~ v || /\A#{MAILBOX_PATTERN}*\z/o !~ v
        raise InvalidComponentError,
          "bad component(expected opaque component): #{v}"
      end

      return true
    end
    private :check_to

    def set_to(v)
      @to = v
    end
    protected :set_to

    def to=(v)
      check_to(v)
      set_to(v)
      v
    end

    def check_headers(v)
      return true unless v
      return true if v.size == 0

      if OPAQUE !~ v || 
          /\A(#{HEADER_PATTERN}(?:\&#{HEADER_PATTERN})*)\z/o !~ v
        raise InvalidComponentError,
          "bad component(expected opaque component): #{v}"
      end

      return true
    end
    private :check_headers

    def set_headers(v)
      @headers = []
      if v
        v.scan(HEADER_REGEXP) do |x|
          @headers << x.split(/=/o, 2)
        end
      end
    end
    protected :set_headers

    def headers=(v)
      check_headers(v)
      set_headers(v)
      v
    end

    def to_s
      @scheme + ':' + 
        if @to 
          @to
        else
          ''
        end + 
        if @headers.size > 0
          '?' + @headers.collect{|x| x.join('=')}.join('&')
        else
          ''
        end +
        if @fragment
          '#' + @fragment
        else
          ''
        end
    end
    #
    # == Usage
    #   require 'uri'
    #
    #   uri = URI.parse("mailto:ruby-list@ruby-lang.org?Subject=subscribe&cc=myaddr")
    #   uri.to_mailtext
    #   # => "To: ruby-list@ruby-lang.org\nSubject: subscribe\nCc: myaddr\n\n\n"
    #
    def to_mailtext
      to = URI::unescape(@to)
      head = ''
      body = ''
      @headers.each do |x|
        case x[0]
        when 'body'
          body = URI::unescape(x[1])
        when 'to'
          to << ', ' + URI::unescape(x[1])
        else
          head << URI::unescape(x[0]).capitalize + ': ' +
            URI::unescape(x[1])  + "\n"
        end
      end

      return "To: #{to}
#{head}
#{body}
"
    end
    alias to_rfc822text to_mailtext
  end

  @@schemes['MAILTO'] = MailTo
end
