out:="build/main"

build flag="":
    odin build src -out:{{out}} {{flag}} 

run arg="":
    just build
    {{out}} {{arg}}

run-debug-gf2 arg="":
    just build -debug
    gf2 --args {{out}} {{arg}}
    
run-debug arg="":
    just build -debug
    {{out}} {{arg}}
