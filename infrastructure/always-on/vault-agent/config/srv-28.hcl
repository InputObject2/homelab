vault {
  address = "VAULT_ADDR_PLACEHOLDER"  # overridden by VAULT_ADDR env var
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "/vault-agent/role-id"
      secret_id_file_path = "/vault-agent/secret-id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "/vault-agent/token"
    }
  }
}

template {
  source      = "/vault-agent/templates/homeassistant.tpl"
  destination = "/secrets/homeassistant/homeassistant.env"
}

template {
  source      = "/vault-agent/templates/matterbridge.tpl"
  destination = "/secrets/matterbridge/matterbridge.env"
}

template {
  source      = "/vault-agent/templates/python-matter-server.tpl"
  destination = "/secrets/python-matter-server/python-matter-server.env"
}

template {
  source      = "/vault-agent/templates/matter-hub.tpl"
  destination = "/secrets/matter-hub/matter-hub.env"
}

template {
  source      = "/vault-agent/templates/esphome.tpl"
  destination = "/secrets/esphome/esphome.env"
}

template {
  source      = "/vault-agent/templates/zigbee2mqtt.tpl"
  destination = "/secrets/zigbee2mqtt/zigbee2mqtt.env"
}

template {
  source      = "/vault-agent/templates/mosquitto.tpl"
  destination = "/secrets/mosquitto/mosquitto.env"
}

template {
  source      = "/vault-agent/templates/voip.tpl"
  destination = "/secrets/voip/voip.env"
}
