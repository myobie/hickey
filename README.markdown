hickey is a wiki
================

Why the name
------------

Because it sucks that much.

Features
--------

* Markdown
* Pretty to read
* New pages can be created at any url
* Search (full text)
* Minor spam protections
* No users or registration (this is a feature, for now)
* Diffs between versions
* Recently updated pages

Required before install
-----------------------

* [git](http://git-scm.com/)
* [ruby](http://www.ruby-lang.org/) (on mac, you already have this)
* [ruby gems](http://docs.rubygems.org/read/chapter/3) (on mac, you already have this)
* heroku gem (`gem install heroku`) (you may need to use `sudo`)

Install
-------

* Clone (`git clone git://github.com/myobie/hickey.git`)

Deploy
------

* `heroku create`
* `git push heroku master`
* `heroku rake db:prepare`
* `heroku open`

Rename your heroku subdomain
----------------------------

* `heroku rename flowers` (flowers being what you want it to be called)

Develop
-------

* Install all gems in .gems
* Create a postgres db called hickey (or pass in DATABASE_URL)
* `rake db:prepare`
* Boot up with shotgun `shotgun config.ru`

Problems
--------

* Postgres only for now. 
* Hard coded SQL in the Page model.

Credit
------

Search code is heavily inspired by: <http://gist.github.com/217158>