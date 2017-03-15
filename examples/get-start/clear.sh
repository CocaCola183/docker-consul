docker-compose stop

docker-compose rm -f

docker volume rm $(docker volume ls -qf dangling=true)