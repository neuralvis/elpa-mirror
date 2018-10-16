elfeed-protocol provide extra protocols to make self-hosting RSS
readers like ownCloud News, Tiny TIny RSS and NewsBlur works with
elfeed.  See the README for full documentation.

Usage:

  ;; curl recommend
  (setq elfeed-use-curl t)
  (elfeed-set-timeout 36000)
  (setq elfeed-curl-extra-arguments '("--insecure")) ;necessary for https without a trust certificate

  ;; setup extra protocol feeds
  (require 'elfeed-protocol)
  (setq elfeed-feeds (list
                      ;; format 1
                      "owncloud+https://user1:pass1@myhost.com"

                      ;; format 2, for password with special characters
                      (list "owncloud+https://user2@myhost.com"
                            :password "password/with|special@characters:")

                      ;; format 3, for password in file
                      (list "owncloud+https://user3@myhost.com"
                            :password-file "~/.password")

                      ;; format 4, for password in .authinfo, ensure (auth-source-search :host "myhost.com" :port "443" :user "user4") exists
                      (list "owncloud+https://user4@myhost.com"
                            :use-authinfo t)

                      ;; format 5, for password in gnome-keyring
                      (list "owncloud+https://user5@myhost.com"
                            :password (shell-command-to-string "secret-tool lookup attribute value"))

                      ;; use autotags
                      (list "owncloud+https://user6@myhost.com"
                            :password "password"
                            :autotags '(("example.com" comic)))))
  (elfeed-protocol-enable)
