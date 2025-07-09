Steps..................................

Create a directory called "jenkins_home"

run "grep docker /etc/group" on your host machine and modify dockerfile with output id

example.............................................

RUN groupadd -g 984 docker || true
984 is the id here
...................................................


run docker compose build

run docker compose up -d
