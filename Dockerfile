FROM phusion/passenger-ruby27

USER app
COPY . /home/app/better-chef-rundeck
WORKDIR /home/app/better-chef-rundeck
RUN cat Gemfile && \
    bundle install

USER root
RUN chown -R app:www-data /home/app/better-chef-rundeck && \
    find /home/app/better-chef-rundeck -type f -exec chmod g+r {} \;
RUN echo 'server {\n\
  listen 80;\n\
  root /home/app/better-chef-rundeck/public;\n\
  passenger_enabled on;\n\
  passenger_user app;\n\
}\n' > /etc/nginx/sites-enabled/chef-rundeck
RUN rm /etc/nginx/sites-enabled/default && rm /etc/service/nginx/down
