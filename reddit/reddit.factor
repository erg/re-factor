! Copyright (C) 2011 John Benediktsson
! See http://factorcode.org/license.txt for BSD license

USING: accessors assocs calendar combinators formatting
http.client json json.reader kernel make math math.statistics
sequences urls utils ;

IN: reddit

<PRIVATE

TUPLE: comment approved_by author author_flair_css_class
author_flair_text banned_by body body_html created created_utc
downs id levenshtein likes link_id link_title name num_reports
parent_id replies edited subreddit subreddit_id ups ;

TUPLE: user comment_karma created created_utc has_mail
has_mod_mail id is_gold is_mod link_karma name ;

TUPLE: story author author_flair_css_class author_flair_text
approved_by banned_by clicked created created_utc domain downs
hidden id is_self levenshtein likes link_flair_css_class
link_flair_text media media_embed name edited num_comments
num_reports over_18 permalink saved score selftext selftext_html
subreddit subreddit_id thumbnail title ups url ;

TUPLE: subreddit created created_utc description display_name id
name over18 subscribers title url ;

: parse-data ( assoc -- obj )
    [ "data" swap at ] [ "kind" swap at ] bi {
        { "t1" [ comment ] }
        { "t2" [ user ] }
        { "t3" [ story ] }
        { "t5" [ subreddit ] }
        [ throw ]
    } case from-slots ;

TUPLE: page url data before after ;

: json-page ( url -- page )
    >url dup http-get nip json> "data" swap at {
        [ "children" swap at [ parse-data ] map ]
        [ "before" swap at [ f ] when-json-null ]
        [ "after" swap at [ f ] when-json-null ]
    } cleave \ page boa ;

: (user) ( username -- data )
    "http://api.reddit.com/user/%s" sprintf json-page ;

: (about) ( username -- data )
    "http://api.reddit.com/user/%s/about" sprintf
    http-get nip json> parse-data ;

: (subreddit) ( subreddit -- data )
    "http://api.reddit.com/r/%s" sprintf json-page ;

: (url) ( url -- data )
    "http://api.reddit.com/api/info?url=%s" sprintf json-page ;

: (search) ( query -- data )
    "http://api.reddit.com/search?q=%s" sprintf json-page ;

: (subreddits) ( query -- data )
    "http://api.reddit.com/reddits/search?q=%s" sprintf json-page ;

: (domains) ( query -- data )
    "http://api.reddit.com/domain/%s" sprintf json-page ;

: next-page ( page -- page' )
    [ url>> ] [ after>> "after" set-query-param ] bi json-page ;

: all-pages ( page -- data )
    [
        [ [ data>> , ] [ dup after>> ] bi ]
        [ next-page ] while drop
    ] { } make concat ;

PRIVATE>

: user-links ( username -- stories )
    (user) data>> [ story? ] filter [ url>> ] map ;

: user-comments ( username -- comments )
    (user) data>> [ comment? ] filter [ body>> ] map ;

: user-karma ( username -- karma )
    (about) link_karma>> ;

: url-score ( url -- score )
    (url) data>> [ score>> ] map-sum ;

: subreddit-links ( subreddit -- links )
    (subreddit) data>> [ url>> ] map ;

: subreddit-top ( subreddit -- )
    (subreddit) data>> [
        1 + "%2d. " printf {
            [ title>> ]
            [ url>> ]
            [ score>> ]
            [ num_comments>> ]
            [
                created_utc>> unix-time>timestamp now swap time-
                duration>hours "%d hours ago" sprintf
            ]
            [ author>> ]
        } cleave
        "%s\n    %s\n    %d points, %d comments, posted %s by %s\n\n"
        printf
    ] each-index ;

: domain-stats ( domain -- stats )
    (domains) all-pages [
        created>> 1000 * millis>timestamp year>>
    ] collect-by [ [ score>> ] map-sum ] assoc-map ;

