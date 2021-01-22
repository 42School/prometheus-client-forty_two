FROM ruby:2.2.3

ENV SRC_HOME /src
RUN mkdir $SRC_HOME
WORKDIR $SRC_HOME

RUN gem install bundler -v 1.13.6

COPY Gemfile* ./
COPY prometheus-client-forty_two.gemspec ./
RUN mkdir -p lib/prometheus/client/forty_two
COPY lib/prometheus/client/forty_two/version.rb lib/prometheus/client/forty_two/
RUN bundle

CMD rspec
