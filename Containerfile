# Use Ruby 3.3.0 (required by Forem)
FROM ruby:3.3.0

# Install Bundler 2.4.17
RUN gem install bundler:2.4.17

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    postgresql-client \
    git \
    curl \
    gnupg2 \
    nodejs \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Yarn via npm (global)
RUN npm install -g yarn

# Set working directory
WORKDIR /app

# Copy .ruby-version, Gemfile, and Gemfile.lock
COPY .ruby-version Gemfile Gemfile.lock ./

# Install gems (skip development/test)
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Install Node.js dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --production

# Copy the rest of the application
COPY . .

# Precompile assets
RUN bundle exec rails assets:precompile

# Expose port 3000
EXPOSE 3000

# Start the Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]