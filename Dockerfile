FROM ruby:2.3

RUN bundle config --global frozen 1
WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock /usr/src/app/
RUN bundle install

COPY . /usr/src/app

CMD ["ruby", "bot.rb"]
