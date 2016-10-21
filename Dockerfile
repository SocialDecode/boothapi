FROM node:4
RUN apt-get -y update && npm install -g coffee-script && npm install -g nodemon

WORKDIR /app
ADD package.json /app/
ADD config.json /app/
RUN npm install
ADD . /app

CMD []

EXPOSE 8081