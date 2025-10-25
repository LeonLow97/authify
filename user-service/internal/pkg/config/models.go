package config

type Config struct {
	Mode   string `mapstructure:"mode"`
	Server struct {
		Name string `mapstructure:"name"`
		Port int    `mapstructure:"port"`
	} `mapstructure:"server"`
	JWTConfig      JWTConfig      `mapstructure:"jwt"`
	PostgresConfig PostgresConfig `mapstructure:"postgres"`
	RedisConfig    RedisConfig    `mapstructure:"redis"`
}
type JWTConfig struct {
	SecretKey string `mapstructure:"secret_key"`
	Expiry    int    `mapstructure:"expiry"`
}
type PostgresConfig struct {
	User     string `mapstructure:"user"`
	Password string `mapstructure:"password"`
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	DB       string `mapstructure:"db"`
}
type RedisConfig struct {
	Address       string `mapstructure:"address"`
	Port          int    `mapstructure:"port"`
	Password      string `mapstructure:"password"`
	DatabaseIndex int    `mapstructure:"database_index"`
}
