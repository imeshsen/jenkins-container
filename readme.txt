Steps for creating Jenkins image..................................

Create a directory called "jenkins_home" to save your data

Run "ls -l /var/run/docker.sock" on your host machine and modify dockerfile with output group id

example............
	ls -l /var/run/docker.sock ------------>srw-rw---- 1 root docker 0 Dec 23 09:24 /var/run/docker.sock


Example.............................................

RUN usermod -aG 0 jenkins
0 is the group id here
...................................................


Run docker compose build

give permission for host by typing..............
	sudo chown -R 1000:1000 jenkins_home
	sudo chmod -R 775 jenkins_home

Run docker compose up -d
