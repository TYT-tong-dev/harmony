import logging
from logging.handlers import RotatingFileHandler
from typing import Optional


def setup_logging(app) -> Optional[logging.Logger]:
	"""
	Initialize application logging.
	- Sets level from app.config['LOG_LEVEL'] (default INFO)
	- Adds a console StreamHandler
	- Optionally adds a RotatingFileHandler if app.config['LOG_FILE'] is set (default 'app.log')
	"""
	try:
		level_name = str(app.config.get('LOG_LEVEL', 'INFO')).upper()
		level = getattr(logging, level_name, logging.INFO)
	except Exception:
		level = logging.INFO

	logger = app.logger
	logger.setLevel(level)

	formatter = logging.Formatter(
		fmt='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
		datefmt='%Y-%m-%d %H:%M:%S'
	)

	# Console handler
	if not any(isinstance(h, logging.StreamHandler) for h in logger.handlers):
		console_handler = logging.StreamHandler()
		console_handler.setLevel(level)
		console_handler.setFormatter(formatter)
		logger.addHandler(console_handler)

	# File handler (rotating)
	log_file = app.config.get('LOG_FILE', 'app.log')
	if log_file:
		try:
			file_handler = RotatingFileHandler(log_file, maxBytes=1_000_000, backupCount=5, encoding='utf-8')
			file_handler.setLevel(level)
			file_handler.setFormatter(formatter)
			logger.addHandler(file_handler)
		except Exception:
			# Swallow file handler errors to avoid breaking app startup
			pass

	logger.debug('Logging initialized')
	return logger


