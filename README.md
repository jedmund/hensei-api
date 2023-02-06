# hensei-api

**hensei-api** is the backend for [granblue.team](https://app.granblue.team/), an app for saving and sharing teams for [Granblue Fantasy](https://game.granbluefantasy.jp).

**Please note that these instructions are a work-in-progress!**

### Installing Ruby

You'll need to install ruby-3.0.0. We recommend using [RVM](https://rvm.io/) and creating a gemset to manage your Ruby installation. Before proceeding, install the GPG keys from the official RVM website.

```
\curl -sSL https://get.rvm.io | bash -s stable
rvm install ruby-3.0.0
rvm use 3.0.0@granblue --create
```

### Installing dependencies

After cloning the repo, install the project dependencies with:

```
bundle install
```

### Creating the database

Once the dependencies have been installed, you'll need to create and seed the database. Seed data is provided but may not be up-to-date!

```
rails db:create
rails db:migrate
rails db:seed
```

### Running the server

Then, you can start the server with:
```
rails server
```
