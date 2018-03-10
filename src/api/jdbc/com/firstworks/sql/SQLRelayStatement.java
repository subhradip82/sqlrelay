package com.firstworks.sql;

import java.sql.*;
import java.util.List;
import java.util.ArrayList;

import com.firstworks.sqlrelay.*;

public class SQLRelayStatement implements Statement {

	private Connection		connection;
	private SQLRConnection		sqlrcon;
	protected SQLRCursor		sqlrcur;
	private List<String>		batch;
	private boolean			closeoncompletion;
	protected SQLRelayResultSet	resultset;
	private int			fetchdirection;
	private int			maxfieldsize;
	private int			maxrows;
	private boolean			poolable;
	protected int			updatecount;
	private boolean			escapeprocessing;

	public SQLRelayStatement() {
		reset();
	}

	private void	reset() {
		connection=null;
		sqlrcon=null;
		sqlrcur=null;
		batch=new ArrayList<String>();
		closeoncompletion=false;
		resultset=null;
		fetchdirection=ResultSet.FETCH_FORWARD;
		maxfieldsize=0;
		maxrows=0;
		poolable=false;
		updatecount=-1;
		escapeprocessing=true;
	}

	public void	setConnection(Connection connection) {
		this.connection=connection;
	}

	public void	setSQLRConnection(SQLRConnection sqlrcon) {
		this.sqlrcon=sqlrcon;
	}

	public void	setSQLRCursor(SQLRCursor sqlrcur) {
		this.sqlrcur=sqlrcur;
	}

	public void 	addBatch(String sql) throws SQLException {
		throwExceptionIfClosed();
		batch.add(sql);
	}

	public void 	cancel() throws SQLException {
		throwExceptionIfClosed();
		throwNotSupportedException();
		// FIXME: maybe we can support this somehow?
	}

	public void 	clearBatch() throws SQLException {
		throwExceptionIfClosed();
		batch.clear();
	}

	public void 	clearWarnings() throws SQLException {
		throwExceptionIfClosed();
	}

	public void 	close() throws SQLException {
		reset();
	}

	public void 	closeOnCompletion() throws SQLException {
		throwExceptionIfClosed();
		closeoncompletion=true;
	}

	public boolean 	execute(String sql) throws SQLException {
		throwExceptionIfClosed();
		// FIXME: handle timeout
		resultset=null;
		updatecount=-1;
		boolean	result=sqlrcur.sendQuery(sql);
		if (result) {
			resultset=new SQLRelayResultSet();
			resultset.setStatement(this);
			resultset.setSQLRCursor(sqlrcur);
		} else {
			throwErrorMessageException();
		}
		return result;
	}

	public boolean 	execute(String sql, int autoGeneratedKeys)
						throws SQLException {
		throwExceptionIfClosed();
		throwNotSupportedException();
		return false;
	}

	public boolean 	execute(String sql, int[] columnIndexes)
						throws SQLException {
		throwExceptionIfClosed();
		throwNotSupportedException();
		return false;
	}

	public boolean 	execute(String sql, String[] columnNames)
						throws SQLException {
		throwExceptionIfClosed();
		throwNotSupportedException();
		return false;
	}

	public int[] 	executeBatch() throws SQLException {
		throwExceptionIfClosed();
		// FIXME: handle timeout
		int[]	results=new int[batch.size()];
		int	count=0;
		for (String sql: batch) {
			results[count++]=executeUpdate(sql);
		}
		return results;
	}

	public ResultSet 	executeQuery(String sql) throws SQLException {
		throwExceptionIfClosed();
		// FIXME: handle timeout
		resultset=null;
		updatecount=-1;
		if (sqlrcur.sendQuery(sql)) {
			resultset=new SQLRelayResultSet();
			resultset.setStatement(this);
			resultset.setSQLRCursor(sqlrcur);
		} else {
			throw new SQLException(sqlrcur.errorMessage());
		}
		return resultset;
	}

	public int 	executeUpdate(String sql) throws SQLException {
		throwExceptionIfClosed();
		// FIXME: handle timeout
		resultset=null;
		updatecount=-1;
		if (sqlrcur.sendQuery(sql)) {
			updatecount=(int)sqlrcur.affectedRows();
		} else {
			throwErrorMessageException();
		}
		return updatecount;
	}

	public int 	executeUpdate(String sql, int autoGeneratedKeys)
						throws SQLException {
		throwExceptionIfClosed();
		throwNotSupportedException();
		return 0;
	}

	public int 	executeUpdate(String sql, int[] columnIndexes)
						throws SQLException {
		throwExceptionIfClosed();
		throwNotSupportedException();
		return 0;
	}

	public int 	executeUpdate(String sql, String[] columnNames)
						throws SQLException {
		throwExceptionIfClosed();
		throwNotSupportedException();
		return 0;
	}

	public Connection 	getConnection() throws SQLException {
		throwExceptionIfClosed();
		return connection;
	}

	public int 	getFetchDirection() throws SQLException {
		throwExceptionIfClosed();
		return fetchdirection;
	}

	public int 	getFetchSize() throws SQLException {
		throwExceptionIfClosed();
		return (int)sqlrcur.getResultSetBufferSize();
	}

	public ResultSet 	getGeneratedKeys() throws SQLException {
		throwExceptionIfClosed();
		throwNotSupportedException();
		// FIXME: maybe we can support this somehow?
		return null;
	}

	public int 	getMaxFieldSize() throws SQLException {
		throwExceptionIfClosed();
		return maxfieldsize;
	}

	public int 	getMaxRows() throws SQLException {
		throwExceptionIfClosed();
		return maxrows;
	}

	public boolean 	getMoreResults() throws SQLException {
		return getMoreResults(Statement.CLOSE_CURRENT_RESULT);
	}

	public boolean 	getMoreResults(int current) throws SQLException {
		throwExceptionIfClosed();
		switch (current) {
			case Statement.CLOSE_CURRENT_RESULT:
				if (resultset!=null) {
					resultset.close();
					resultset=null;
					updatecount=-1;
				}
				// FIXME: we could support this...
				return false;
			case Statement.KEEP_CURRENT_RESULT:
				throwNotSupportedException();
				return false;
			case Statement.CLOSE_ALL_RESULTS:
				throwNotSupportedException();
				return false;
			default:
				throwNotSupportedException();
				return false;
		}
	}

	public int 	getQueryTimeout() throws SQLException {
		throwExceptionIfClosed();
		throwNotSupportedException();
		// FIXME: this can be supported
		//return sqlrcon.getResponseTimeout();
		return 0;
	}

	public ResultSet 	getResultSet() throws SQLException {
		throwExceptionIfClosed();
		return resultset;
	}

	public int 	getResultSetConcurrency() throws SQLException {
		throwExceptionIfClosed();
		// FIXME: is this correct?
		return ResultSet.CONCUR_READ_ONLY;
	}

	public int 	getResultSetHoldability() throws SQLException {
		throwExceptionIfClosed();
		// FIXME: is this correct?
		return ResultSet.CLOSE_CURSORS_AT_COMMIT;
	}

	public int 	getResultSetType() throws SQLException {
		throwExceptionIfClosed();
		return ResultSet.TYPE_FORWARD_ONLY;
	}

	public int 	getUpdateCount() throws SQLException {
		throwExceptionIfClosed();
		return updatecount;
	}

	public SQLWarning 	getWarnings() throws SQLException {
		throwExceptionIfClosed();
		return null;
	}

	public boolean 	isClosed() throws SQLException {
		return sqlrcur==null;
	}

	public boolean 	isCloseOnCompletion() throws SQLException {
		throwExceptionIfClosed();
		return false;
	}

	public boolean 	isPoolable() throws SQLException {
		throwExceptionIfClosed();
		return poolable;
	}

	public void 	setCursorName(String name) throws SQLException {
		throwExceptionIfClosed();
		throwNotSupportedException();
	}

	public void 	setEscapeProcessing(boolean enable)
						throws SQLException {
		throwExceptionIfClosed();
		escapeprocessing=enable;
		// FIXME: do something with this...
	}

	public void 	setFetchDirection(int direction) throws SQLException {
		throwExceptionIfClosed();
		fetchdirection=direction;
	}

	public void 	setFetchSize(int rows) throws SQLException {
		throwExceptionIfClosed();
		sqlrcur.setResultSetBufferSize(rows);
	}

	public void 	setMaxFieldSize(int max) throws SQLException {
		throwExceptionIfClosed();
		maxfieldsize=max;
	}

	public void 	setMaxRows(int max) throws SQLException {
		throwExceptionIfClosed();
		maxrows=max;
	}

	public void 	setPoolable(boolean poolable) throws SQLException {
		throwExceptionIfClosed();
		this.poolable=poolable;
	}

	public void 	setQueryTimeout(int seconds) throws SQLException {
		throwExceptionIfClosed();
		// FIXME: hmm... this is at the connection level
		sqlrcon.setResponseTimeout(seconds,0);
	}

	public boolean	isWrapperFor(Class<?> iface) throws SQLException {
		// FIXME: implement this for SQLRCursor and SQLRConnection
		return false;
	}

	public <T> T	unwrap(Class<T> iface) throws SQLException {
		// FIXME: implement this for SQLRCursor and SQLRConnection
		return null;
	}

	protected void throwExceptionIfClosed() throws SQLException {
		if (sqlrcur==null) {
			throw new SQLException("FIXME: Statement is closed");
		}
	}

	protected void throwErrorMessageException() throws SQLException {
		throw new SQLException(sqlrcur.errorMessage());
	}

	protected void throwNotSupportedException() throws SQLException {
		throw new SQLFeatureNotSupportedException();
	}
};
