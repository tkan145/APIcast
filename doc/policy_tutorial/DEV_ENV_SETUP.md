# Setting up the development environment

As was clear from the introduction, APIcast policies are created in the Lua programming language. So we need to setup an environment to do some Lua programming. Also, an actual APIcast server would be very nice to perform some local tests.

Luckily APIcast makes it very easy to setup a development environment for APIcast using Docker and Docker Compose.

### prerequisites
This means both Docker and Docker compose must be installed.

The version of Docker I currently use is:

    Docker version 19.03.8

Instructions for installing Docker can be found on the Docker [website](https://docs.docker.com/get-docker/).

With Docker compose version:

    docker-compose version 1.25.4

Instructions for installing Docker-compose can also be found on the Docker [website](https://docs.docker.com/compose/install/).

### Setting up the development image
Now that we have both Docker and Docker-compose installed we an setup the APIcast development image.

Firstly the APIcast git repostitory must be cloned so we can start the development of our policy. Since we are going to base our policy on the latest 3scale release we are switching to the stable branch of APIcast.

```shell
git clone https://github.com/3scale/apicast.git
```

when done switch to a stable branch, I am using 3.8
```shell
cd apicast/
git checkout 3.8-stable
```

To start the APIcast containers using Docker-compose we can use the Make file provided by 3scale. In the APIcast directory simply execute the command:
```shell
make development
```

![make-development](img/make-development.png)

The Docker container starts in the foreground with a bash session. The first thing we need to do inside the container is installing all the dependencies.

This can also be done using a Make command, which again must be issued **inside** the container.
```shell
make dependencies
```
It will now download and install a plethora of dependencies inside the container.

The output will be very long, but if everything went well you should be greeted with an output that looks something like this:

![make-dependencies](img/make-dependencies.png)

Now as a final verification we can run some APIcast unit tests to see if we are up and running and ready to start the development of our policy.

To run the Lua unit tests run the following command **inside** the container:

```shell
make busted
```
![make-busted](img/make-busted.png)

Now that we can successfully run unit tests we can start our policy development!

The project’s source code will be available in the container and sync’ed with your local apicast directory, so you can edit files in your preferred environment and still be able to run whatever you need inside the Docker container.

The development container for APIcast uses a Docker volume mount to mount the local apicast directory inside the container. This means all files changed locally in the repository are synced with the container and used in the tests and runtime of the development container.

![APIcast-dev-container-mount](img/apicast-dev-container-mount.png)

It also means you can use your favorite IDE or editor develop your APIcast policy.

### Stopping the development container
Stopping the development environment container is a two step process. In the interactive Bash session simple press:

```
Ctrl + C
```

This exits the foreground bash shell, but the containers are still running. Execute the following make command to cleanly stop all containers:

```shell
$ make stop-development
docker-compose -f docker-compose-devel.yml -f docker-compose-devel-volmount-mac.yml down
Stopping apicast_build_0_development_1 ... done
Stopping apicast_build_0_redis_1       ... done
Removing apicast_build_0_development_1 ... done
Removing apicast_build_0_redis_1       ... done
Removing network apicast_build_0_default
```

Now we are ready to create a 3scale APIcast policy. The next step in the tutorial is [here](POLICY_SCAFFOLD.md)