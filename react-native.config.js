// https://github.com/react-native-community/cli/blob/main/docs/dependencies.md
// Required for React Native autolinking (@react-native-community/cli) to pick
// up the plugin's Package class on both platforms.

module.exports = {
	dependency: {
		platforms: {
			ios: {},
			android: {},
		},
	},
}
