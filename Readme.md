Show the dependencies of your private repos

Install
=======

    gem install repo_dependency_graph

Usage
=====
Install [graphviz](http://www.graphviz.org/Download_macos.php)

```Bash
repo-dependency-graph --organization xyz --token ttttoookkkeeeennn
```

### Token for private repos

```Bash
# create a token that has access to your repositories
curl -v -u your-user-name -X POST https://api.github.com/authorizations --data '{"scopes":["repo"]}'
enter your password -> TOKEN

repo-dependency-graph --organization your-org --token TOKEN
```

TODO
====
 - work for public repos
 - switch between runtime-dependency / development-dependency / any
 - `--ignore` flag

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/repo_dependency_graph.png)](https://travis-ci.org/grosser/repo_dependency_graph)
