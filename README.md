Twitter Graph Segmenter
=======================

This project will attempt to segment a twitter users graph (such as KAIST one) in weeks using just the sign up date of the users.

## Technical Requirements

Project has been developed under **Ruby 2.1.1** using **bundler** to store and install used gems.

If you are familiar with Ruby and Bundler you can skip until the data requirements section, as there's nothing new here for you.

If you aren't experienced with Ruby here are some instructions for installing this project.

Unfortunately this instructions are for installations on a Linux (Debian or Ubuntu, in fact) as it is my work environment. I'm quite confident that this instructions may work on Mac too, but I can't guarantee it.

If you manage to install the project in other OS, please send me the instructions and I will append them here.

### GIT

Git is a distributed revision control system. You can install it using *apt* wit the following command `apt-get install git`.

Git use is only mandatory if you want to clone or fork this repository. Otherwise you can just download the ZIP file at Github repo: https://github.com/wild-fire/twitter-graph-segmenter

### RVM

First, download RVM from https://rvm.io/. RVM is a Ruby Version Manager that allows you to easily install rubies in your machine. I personally love it :)

If you don't want to read all the website just type in bash `curl -sSL https://get.rvm.io | bash`.

### Ruby 2.1.1

Once you have installed RVM, installing Ruby 2.1.1 is as easy as typing `rvm install 2.1.1`

## Installing the scripts

### Downloading the code

You can fork or clone this repo to download the code. If you don't want to use GIT then you can just download the zip file from Github.

### Setting Up RVM and installing gems

Enter your code directory and run `rvm use 2.1.1@twitter-graph-segmenter --create --ruby-version`. This will create a RVM gemset and set this folder pointing to that gemset.

Now you can run `bundle install` and install all the required gems. If you receive an error because `bundle` is not recognized just run `gem install bundler` and then `bundle install`

## Executing the scripts

This repo have three scripts within: tw-fetch-users, tw-week-user and tw-segment-graph. They are run just by typing `bin/tw-fetch-users.rb, bin/tw-week-user.rb` or `bin/tw-segment-graph.rb`.

If files are not executable you can add the execution permission on them using chmod `chmod +X bin/*.rb`.

You can add help command (`bin/tw-week-user.rb help`) to see a command list and use the help option in any command (i.e. `bin/tw-week-user.rb file --help`)

### Last user of the week

`find` command takes two username and displays the last user for every week between the signup dates of those users.

`bin/tw-week-user.rb find pud goldman`

`file` command takes a file of first beacons and returns the last users for every week between two adjacent lines in the file. See the *data requirements* section for more info.

### Segment graph

`segment` command takes a users graph file and a list of user ids and their signup date. As a return it will return a series of files (one for each user in the list) containing just the lines of the graph file that involve user ids less than the current limit.

### Fetch users

`fetch` command in the bin/tw-fetch-users script allows you to fetch all users profile from the `first_user_id` to the `last_user_id` and flush the information (user id, screen name and signup date) to a TSV file.

## Data Requirements

Of course, this project also needs data to return results.

### Users Graph

Users graph will be stored in a TSV (tab-separated values) file. Each line of the file will store a relationship between the two users whose ids are in the line. i.e: In the following file user 12 is related to users 13,14,15,16,17,18 and 20 and user 13 is related to users 12,17,19,21,25,33 and 37.

```tsv
12	13
12	14
12	15
12	16
12	17
12	18
12	20
...
13	12
13	17
13	19
13	21
13	25
13	33
13	37
...
```

Users graph file will also be used for the `segment` command under the `bin/tw-segment-graph.rb` script.

### First Beacons

First beacons file is a file containing user ids and sign up dates for those users in a TSV format. i.e:


```tsv
291	2006/05/20
3475	2006/07/31
```

First beacons file will be used as input by the `file` command under the `bin/tw-week-user.rb` script. This command will get every pair of lines and try to find the last user of every week between them.

The more beacons we have, the more focused the search will be, but using too much beacons would be rather useless as there may not be an end of the week between two lines.

### More beacons

Although a highly detailed file of beacons for the first beacons file may be inadequate, we can provide an additional file plenty of beacons following the same format but adding the signup time.

```
12	2006-03-21T20:50:14+00:00
13	2006-03-21T20:51:43+00:00
15	2006-03-21T21:00:54+00:00
20	2006-03-21T21:02:31+00:00
53	2006-04-01T01:55:49+00:00
107	2006-04-14T06:41:38+00:00
```

This file will be used for the `file` and `find` commands under the `bin/tw-week-user.rb` script to accelerate the search as they provide information about which users fall out of the desired week.

## Data Output

### Last users of the week

`file` and `find` commands under the `bin/tw-week-user.rb` return the last users of each week between the users given as input (as an argument of the `find` command or inside the first beacons file for the `file` command).

`find` command returns it as a message on the standard output.

`file` command stores them in a TSV file with the same format than the beacons file:

```
47	kellan	2006-03-24 04:13:02 +0100
70	shannon	2006-04-01 21:30:51 +0200
96	garo	2006-04-09 19:31:28 +0200
108	ilona	2006-04-14 08:42:02 +0200
```

### Segmented graph file

`segment` command under the `bin/tw-segment-graph.rb` script writes a users graph file containing the users until some limit with the same format than the original users graph file (TSV).

## Contribute

You can fork the repo and do any modification you want (including documentation). Then make a pull request so I can consider its inclusion in my repo.

You can also discuss anything in the issues section. Any comment will be appreciated.
