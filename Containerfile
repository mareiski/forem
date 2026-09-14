# Use Ruby 3.1.4 (Forem's requirement)
FROM ruby:3.1.4

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
    yarnpkg \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install gems (skip development/test)
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3 --without development test

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