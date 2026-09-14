# Use the official Ruby image
FROM ruby:3.1.4

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y build-essential gnupg2 curl less git && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js (for asset compilation)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Set working directory
WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# Install Node.js dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy the rest of the application
COPY . .

# Precompile assets (for production)
RUN bundle exec rails assets:precompile

# Expose port 3000
EXPOSE 3000

# Start the Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]