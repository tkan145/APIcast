local parser = require 'resty.url_helper'

describe('URL parser helper', function()
  describe('.parse', function()
    describe('Basic Auth', function()
        it('parses user and password from the url', function()
          local auth, err, parsed_url
          local url = 'http://foo:bar@example.com'

          parsed_url, auth, err = parser.parse_url_auth(url)
          assert.is.falsy(err)
          assert.equal("http://example.com", parsed_url)
          assert.equal("Basic Zm9vOmJhcg==", auth)
        end)

        it('blank password from the url', function()
          local auth, err, parsed_url
          local url = 'http://foo:@example.com'

          parsed_url, auth, err = parser.parse_url_auth(url)
          assert.is.falsy(err)
          assert.equal("http://example.com", parsed_url)
          assert.equal("Basic Zm9vOg==", auth)
        end)

        it('blank username', function()
          local auth, err, parsed_url
          local url = 'http://:bar@example.com'

          parsed_url, auth, err = parser.parse_url_auth(url)
          assert.is.falsy(err)
          assert.equal("http://example.com", parsed_url)
          assert.equal("Basic OmJhcg==", auth)
        end)

        it('blank username and blank password', function()
          local auth, err, parsed_url
          local url = 'http://example.com'

          parsed_url, auth, err = parser.parse_url_auth(url)
          assert.is.falsy(err)
          assert.equal("http://example.com", parsed_url)
          assert.is.falsy(auth)
        end)

        it('leading // without scheme with user info', function()
          local url = '//user@example.com'

          local _, _, err = parser.parse_url_auth(url)
          assert.is.not_false(err)
          assert.equal(err, "missing scheme")
        end)
    end)
  end)
end)
