### tarantool web kv storage daemon

For launch you need:  
* [tarantool-http](https://github.com/tarantool/http)

* configure env values:
    ```bash
    export LISTEN_URI=3301
    export SERVER_IP=127.0.0.1
    export SERVER_PORT=8080
    tarantool myapp.lua
    ```


1) POST /kv body: {key: "test", "value": {SOME ARBITRARY JSON}} 
2) PUT kv/{id} body: {"value": {SOME ARBITRARY JSON}} 
3) GET kv/{id} 
4) DELETE kv/{id} 

- POST возвращает 409 если ключ уже существует, 
- POST, PUT возвращают 400 если боди некорректное 
- PUT, GET, DELETE возвращает 404 если такого ключа нет - все операции логируются