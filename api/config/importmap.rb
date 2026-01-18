# Pin npm packages by running ./bin/importmap

pin 'application', preload: true
pin '@hotwired/turbo-rails', to: 'https://cdn.jsdelivr.net/npm/@hotwired/turbo-rails@8.0.12/+esm'
pin '@hotwired/stimulus', to: 'https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/+esm'

pin_all_from 'app/javascript/controllers', under: 'controllers'
