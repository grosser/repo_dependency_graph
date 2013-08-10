Show the dependencies of your repos

Install
=======

    gem install repo_dependency_graph

Usage
=====
Install [graphviz](http://www.graphviz.org/Download_macos.php)

<!-- update from ./bin/repo-dependency-graph -h -->
        --token TOKEN                Use token
        --user USER                  Use user
        --organization ORGANIZATION  Use user
        --private                    Only show private repos
    -h, --help                       Show this.
    -v, --version                    Show Version

### Public user

```Bash
repo-dependency-graph --user repo-test-user
repo_a: repo_b, repo_c
repo_c: repo_b
```
![Simple](http://dl.dropbox.com/u/2670385/Web/repo_dependency_graph_simple.png)

### Private organization

```Bash
# create a token that has access to your repositories
curl -v -u your-user-name -X POST https://api.github.com/authorizations --data '{"scopes":["repo"]}'
enter your password -> TOKEN

repo-dependency-graph --organization xyz --token ttttoookkkeeeennn
```

TODO
====
 - switch between runtime-dependency / development-dependency / any
 - `--ignore / --pattern` flag
 - `--chef` flag

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/repo_dependency_graph.png)](https://travis-ci.org/grosser/repo_dependency_graph)
