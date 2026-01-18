#
# Postfacto, a free, open-source and self-hosted retro tool aimed at helping
# remote teams.
#
# Copyright (C) 2016 - Present Pivotal Software, Inc.
#
# This program is free software: you can redistribute it and/or modify
#
# it under the terms of the GNU Affero General Public License as
#
# published by the Free Software Foundation, either version 3 of the
#
# License, or (at your option) any later version.
#
#
#
# This program is distributed in the hope that it will be useful,
#
# but WITHOUT ANY WARRANTY; without even the implied warranty of
#
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#
# GNU Affero General Public License for more details.
#
#
#
# You should have received a copy of the GNU Affero General Public License
#
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
FROM ruby:3.3.6-alpine

RUN gem install bundler

COPY ./api /postfacto
COPY docker/release/entrypoint /

WORKDIR /postfacto

# Nokogiri dependencies
RUN apk add --update \
  build-base \
  libxml2-dev \
  libxslt-dev

RUN apk add --update \
  mariadb-dev \
  postgresql-dev \
  sqlite-dev

RUN apk add --update nodejs

RUN bundle config build.nokogiri --use-system-libraries
RUN bundle install --without test

RUN bundle exec rake assets:precompile

ENV RAILS_ENV production
ENV RAILS_SERVE_STATIC_FILES true
ENV GOOGLE_OAUTH_CLIENT_ID ""
ENV ENABLE_ANALYTICS false

EXPOSE 4000

ENTRYPOINT "/entrypoint"
