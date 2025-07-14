Steps..................................

Create a directory called "jenkins_home" to save your data

Run "grep docker /etc/group" on your host machine and modify dockerfile with output id (example: 984)

Example.............................................

RUN groupadd -g 984 docker || true
984 is the id here
...................................................


Run docker compose build

Run docker compose up -d
