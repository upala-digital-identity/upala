import MyComponent from './MyComponent'
import { drizzleConnect } from '@drizzle/react-plugin'

const mapStateToProps = state => ({
  accounts: state.accounts,
  SimpleStorage: state.contracts.SimpleStorage,
  TutorialToken: state.contracts.TutorialToken,
  drizzleStatus: state.drizzleStatus
})

const MyContainer = drizzleConnect(
  MyComponent,
  mapStateToProps
)

export default MyContainer
