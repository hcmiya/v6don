module Twitter
  class Regex
    REGEXEN[:valid_domain] = Regexp.new REGEXEN[:valid_domain].to_s.sub('|onion', '|i2p|onion')
    REGEXEN[:valid_general_url_path_chars] = /[\/\w\p{Letter}\p{Emoji}\-.~!$&'()*+,;=%:@#?]/iou
    REGEXEN[:valid_url_path_ending_chars] = /[\/\w\p{Letter}\p{Emoji}\-~!$&'()*+;=:#?]|(?:#{REGEXEN[:valid_url_balanced_parens]})/iou
    REGEXEN[:valid_url_balanced_parens] = /
      \(
        (?:
          #{REGEXEN[:valid_general_url_path_chars]}+
          |
          # allow one nested level of balanced parentheses
          (?:
            #{REGEXEN[:valid_general_url_path_chars]}*
            \(
              #{REGEXEN[:valid_general_url_path_chars]}+
            \)
            #{REGEXEN[:valid_general_url_path_chars]}*
          )
        )
      \)
    /iox
    REGEXEN[:valid_url_path] = /(?:
      (?:
        #{REGEXEN[:valid_general_url_path_chars]}*
        (?:#{REGEXEN[:valid_url_balanced_parens]} #{REGEXEN[:valid_general_url_path_chars]}*)*
        #{REGEXEN[:valid_url_path_ending_chars]}
      )|(?:#{REGEXEN[:valid_general_url_path_chars]}+\/)
    )/iox
    REGEXEN[:valid_url] = %r{
      (                                                                                     #   $1 total match
        (#{REGEXEN[:valid_url_preceding_chars]})                                            #   $2 Preceding character
        (                                                                                   #   $3 URL
          ((https?|dat|dweb|ipfs|ipns|ssb|gopher):\/\/)?                                    #   $4 Protocol (optional)
          (#{REGEXEN[:valid_domain]})                                                       #   $5 Domain(s)
          (?::(#{REGEXEN[:valid_port_number]}))?                                            #   $6 Port number (optional)
          (/#{REGEXEN[:valid_url_path]}*)?                                                  #   $7 URL Path and anchor
          (\?#{REGEXEN[:valid_url_query_chars]}*#{REGEXEN[:valid_url_query_ending_chars]})? #   $8 Query String
        )
      )
    }iox
  end
end
