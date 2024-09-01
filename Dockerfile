#
# Chromedriver Dockerfile
#
FROM ghcr.io/clispios/basedriver:master

# Install the latest versions of Google Chrome and Chromedriver:
RUN export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install --no-install-recommends --no-install-suggests -y \
    unzip \
    gnupg \
    # Reverse proxy for chromedriver:
    nginx \
  && GOOGLE_LINUX_DL=https://dl.google.com/linux \
  && curl -sL "$GOOGLE_LINUX_DL/linux_signing_key.pub" | apt-key add - \
  && curl -sL "$GOOGLE_LINUX_DL/direct/google-chrome-stable_current_amd64.deb" \
    > /tmp/chrome.deb \
  && apt install --no-install-recommends --no-install-suggests -y \
    /tmp/chrome.deb \
  && CHROMIUM_FLAGS='--no-sandbox --disable-dev-shm-usage' \
  # Patch Chrome launch script and append CHROMIUM_FLAGS to the last line:
  && sed -i '${s/$/'" $CHROMIUM_FLAGS"'/}' /opt/google/chrome/google-chrome \
  && CHROME_VERSION=$(google-chrome --product-version | grep -o "[^\.]*\.[^\.]*\.[^\.]*") \
  && CHROMEDRIVER_VERSION=$(wget -qO- "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_$CHROME_VERSION") \
  && curl -sL https://storage.googleapis.com/chrome-for-testing-public/${CHROMEDRIVER_VERSION}/linux64/chromedriver-linux64.zip -o /tmp/driver.zip \
  && unzip /tmp/driver.zip \
  && chmod 755 chromedriver-linux64/chromedriver \
  && mv chromedriver-linux64/chromedriver /usr/local/bin/ \
  # Remove obsolete files:
  && apt-get autoremove --purge -y \
    unzip \
    gnupg \
  && apt-get clean \
  && rm -rf \
    chromedriver-linux64 \
    /tmp/* \
    /usr/share/doc/* \
    /var/cache/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# Configure nginx to run in a container context:
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log
RUN chown -R webdriver:webdriver /var/lib/nginx
RUN touch /run/nginx.pid && chown -R webdriver:webdriver /run/nginx.pid

COPY nginx.conf /etc/nginx/
COPY reverse-proxy.sh /usr/local/bin/reverse-proxy

USER webdriver

ENTRYPOINT ["entrypoint", "reverse-proxy", "chromedriver"]

# Bind chromedriver to port 5555:
CMD ["--port=5555"]

# Expose nginx on port 4444, forwarding to chromedriver on port 5555:
EXPOSE 4444
