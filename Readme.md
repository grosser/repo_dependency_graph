Graph the dependency of your repositories

Install
=======

```Bash
gem install repo_dependency_graph
```

Usage
=====
Install [graphviz](http://www.graphviz.org/Download_macos.php)

<!-- update from bundle exec ruby ./bin/repo-dependency-graph -h -->
        --token TOKEN                Use token
        --user USER                  Use user
        --draw TYPE                  png, html, table (default: png)
        --organization ORGANIZATION  Use organization
        --private                    Only show private repos
        --external                   Also include external projects in graph (can get super-messy)
        --map SEARCH=REPLACE         Replace in project name to find them as internal: 'foo=bar' -> replace foo in repo names to bar
        --only TYPE                  Only this type (chef,gem), default: all
        --select REGEX               Only include repos with matching names
        --reject REGEX               Exclude repos with matching names
    -h, --help                       Show this.
    -v, --version                    Show Version
<!-- end -->

### Public user

```Bash
repo-dependency-graph --user repo-test-user
repo_a: repo_b, repo_c
repo_b: repo_d
repo_d: repo_c
repo_c: repo_b
repo_e: repo_a, repo_b, repo_c, repo_d
repo_f: repo_c, repo_d
```
<!--
d = {
  "repo_a" => ["repo_b", "repo_c"],
  "repo_b" => ["repo_d"],
  "repo_d" => ["repo_c"],
  "repo_c" => ["repo_b"],
  "repo_e" => ["repo_a", "repo_b", "repo_c", "repo_d"],
  "repo_f" => ["repo_c", "repo_d"],
}
draw(d)
-->
![Simple](assets/simple.png?raw=true)
![Travis](assets/travis-internal.png?raw=true)

### Private organization

```Bash
# create a token that has access to your repositories
curl -v -u your-user-name -X POST https://api.github.com/authorizations --data '{"scopes":["repo"]}'
enter your password -> TOKEN

git config --global github.token ttttoookkkeeeennn

OR

repo-dependency-graph --organization xyz --token ttttoookkkeeeennn
```

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/repo_dependency_graph.png)](https://travis-ci.org/grosser/repo_dependency_graph)
