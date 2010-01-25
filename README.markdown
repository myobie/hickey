hickey is a wiki
================

Why
---

It was a fun few hours.

Features
--------

* Can edit any page with markdown
* Pretty to read (relies heavily on the base stylesheet of the browser, for now)
* New pages can be created at any url by linking or just visiting that url
* Search
* Minor spam protections
* No users or registration (this is a feature, for now)

Gems
----

Look at .gems to see what gems it uses. 

Install
-------

* Checkout
* Boot up with shotgun `shotgun config.ru`

Deploy
------

* `heroku create`
* `git push heroku master`
* `heroku rake db:prepare`
* `heroku open`

Credit
------

Search code is heavily inspired by: <http://gist.github.com/217158>